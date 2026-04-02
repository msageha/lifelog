import { promises as fs } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { OpenClawApi, HttpHandler, OpenClawLogger, OpenClawRuntime } from "./types.js";
import { verifyAuth } from "./auth.js";
import { RateLimiter } from "./rate-limiter.js";
import { getReactionSettings, type ReactionSettings } from "./recall-settings.js";
import { readBody, sendError, sendJson, PayloadTooLargeError } from "./http.js";
import { FileWriteQueue } from "./file-write-queue.js";

const MEMORY_ROOT = join(homedir(), ".openclaw", "workspace", "memory");
const STATE_PATH = join(MEMORY_ROOT, "voice-transcript-state.json");
const MAX_SEGMENTS = 20;
const MIN_FIRE_CHARS = 50;
const BUFFER_TTL_MS = 30 * 60 * 1000; // 30 minutes
const DEDUP_TTL_MS = 60 * 1000; // 60s dedup window

const fileWriteQueue = new FileWriteQueue();

const _sentIds = new Map<string, number>();
function isDuplicate(key: string): boolean {
  const now = Date.now();
  if (_sentIds.has(key) && now - _sentIds.get(key)! < DEDUP_TTL_MS) return true;
  _sentIds.set(key, now);
  for (const [k, t] of _sentIds) {
    if (now - t > DEDUP_TTL_MS) _sentIds.delete(k);
  }
  return false;
}

interface TranscriptSegment {
  speaker?: string;
  text?: string;
}

interface TranscriptData {
  event?: string;
  recording_id?: string;
  duration_sec?: number;
  speaker_count?: number;
  language?: string;
  started_at?: string;
  segments?: TranscriptSegment[];
}

interface BufferEntry {
  timestamp: number;
  full_text: string;
  duration_sec: number;
  speaker_count: number;
  language: string;
  started_at?: string;
}

const recentTranscripts: BufferEntry[] = [];

function trimBuffer(): void {
  const cutoff = Date.now() - BUFFER_TTL_MS;
  while (recentTranscripts.length > 0 && recentTranscripts[0].timestamp < cutoff) {
    recentTranscripts.shift();
  }
}

function extractFullText(data: TranscriptData): string {
  const segments = data.segments || [];
  return segments
    .map((seg) => (seg.text || "").replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .join(" ");
}

function addToBuffer(data: TranscriptData): void {
  const fullText = extractFullText(data);
  recentTranscripts.push({
    timestamp: Date.now(),
    full_text: fullText,
    duration_sec: Math.round(data.duration_sec || 0),
    speaker_count: data.speaker_count || 0,
    language: data.language || "?",
    started_at: data.started_at,
  });
  trimBuffer();
}

function buildContextSummary(): string {
  const past = recentTranscripts.slice(0, -1);
  if (past.length === 0) return "";
  const lines = past.map((t) => {
    const time = t.started_at
      ? new Date(t.started_at).toLocaleTimeString("ja-JP", {
          timeZone: "Asia/Tokyo",
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        })
      : "??:??";
    const preview = t.full_text.length > 80 ? t.full_text.slice(0, 80) + "..." : t.full_text;
    return `\u{1F399} ${time} [${t.speaker_count} speaker${t.speaker_count !== 1 ? "s" : ""}, ${t.duration_sec}s] ${t.language} \u2014 ${preview}`;
  });
  return "\n\n\u3010\u904E\u53BB30\u5206\u306E\u4F1A\u8A71\u30B5\u30DE\u30EA\u30FC\u3011\n" + lines.join("\n");
}

function formatJstTime(ts: Date): string {
  return ts.toLocaleTimeString("ja-JP", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function formatJstDate(ts: Date): string {
  return ts.toLocaleDateString("en-CA", { timeZone: "Asia/Tokyo" });
}

async function appendDiaryEntry(data: TranscriptData, log: OpenClawLogger | undefined): Promise<void> {
  const startedAt = data.started_at ? new Date(data.started_at) : new Date();
  const dateStr = formatJstDate(startedAt);
  const timeStr = formatJstTime(startedAt);
  const durationSec = Math.round(data.duration_sec || 0);
  const lang = data.language || "?";
  const speakerCount = data.speaker_count || 0;

  const header = `\u{1F399} ${timeStr} - [${speakerCount} speaker${speakerCount !== 1 ? "s" : ""}, ${durationSec}s] ${lang}\n`;

  let body = "";
  const segments = data.segments || [];
  for (const seg of segments.slice(0, MAX_SEGMENTS)) {
    const speaker = seg.speaker || "?";
    const text = (seg.text || "").replace(/\s+/g, " ").trim();
    if (text) {
      body += `   ${speaker}: ${text}\n`;
    }
  }
  if (segments.length > MAX_SEGMENTS) {
    body += `   ... (${segments.length - MAX_SEGMENTS} more segments)\n`;
  }

  const diaryPath = join(MEMORY_ROOT, `${dateStr}.md`);
  try {
    await fileWriteQueue.enqueue(diaryPath, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.appendFile(diaryPath, `${header}${body}`, { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`voice-transcript: failed to append diary: ${(err as Error).message}`);
  }
}

async function persistState(data: TranscriptData, log: OpenClawLogger | undefined): Promise<void> {
  const state = {
    recording_id: data.recording_id,
    duration_sec: data.duration_sec,
    speaker_count: data.speaker_count,
    language: data.language,
    started_at: data.started_at,
    updatedAt: new Date().toISOString(),
    source: "voice-transcript",
  };
  try {
    await fileWriteQueue.enqueue(STATE_PATH, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.writeFile(STATE_PATH, JSON.stringify(state, null, 2), { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`voice-transcript: failed to persist state: ${(err as Error).message}`);
  }
}

function buildDeliveryDirective(settings: ReactionSettings): string {
  const channels: string[] = [];
  if (settings.lineDeliveryEnabled) channels.push("LINE");
  if (settings.vibetermDeliveryEnabled) channels.push("Vibeterm");
  if (channels.length === 0) return "\n\u3010\u914D\u4FE1\u5148\u3011\u306A\u3057\uFF08\u914D\u4FE1\u30B9\u30AD\u30C3\u30D7\uFF09";
  return `\n\u3010\u914D\u4FE1\u5148\u3011${channels.join(", ")}`;
}

function buildEventText(data: TranscriptData, settings: ReactionSettings): string {
  const segments = data.segments || [];
  const durationSec = Math.round(data.duration_sec || 0);
  const lang = data.language || "?";
  const speakerCount = data.speaker_count || 0;

  const lines = [
    "\u{1F399} \u3054\u4E3B\u4EBA\u69D8\u306E\u4F1A\u8A71\u304C\u6587\u5B57\u8D77\u3053\u3057\u3055\u308C\u305F\u3002voice-react \u30B9\u30AD\u30EB\u3067\u53CD\u5FDC\u3057\u3066\u3002",
    "\u3010\u8FD4\u4FE1\u30EB\u30FC\u30EB\u3011\u8FD4\u4FE1\u306E\u5148\u982D\u884C\u306B\u300C\ud83c\udfa4 \u4F1A\u8A71\u3088\u308A\u300D\u3092\u5FC5\u305A\u542B\u3081\u308B\u3053\u3068\u3002",
    `\u8A71\u8005\u6570: ${speakerCount} / \u8A00\u8A9E: ${lang} / \u6642\u9593: ${durationSec}\u79D2`,
    "",
    "\u3010\u76F4\u524D\u306E\u4F1A\u8A71\u3011",
  ];

  for (const seg of segments.slice(0, MAX_SEGMENTS)) {
    const speaker = seg.speaker || "?";
    const text = (seg.text || "").replace(/\s+/g, " ").trim();
    if (text) {
      lines.push(`${speaker}: ${text}`);
    }
  }

  const context = buildContextSummary();
  if (context) {
    lines.push(context);
  }

  lines.push(buildDeliveryDirective(settings));

  return lines.join("\n");
}

export function createVoiceTranscriptHandler(api: OpenClawApi): HttpHandler {
  const gatewayToken = api.config?.gateway?.auth?.token;
  const log = api.logger;
  const runtime = api.runtime;

  if (!gatewayToken) {
    throw new Error("voice-transcript: gateway auth token is required but not configured");
  }

  const rateLimiter = new RateLimiter({ maxRequests: 60, windowMs: 60_000 });

  if (!runtime?.subagent?.run) {
    log?.warn?.("voice-transcript: runtime.subagent.run NOT available");
  }

  async function trySendChat(data: TranscriptData): Promise<void> {
    if (!runtime?.subagent?.run) {
      log?.warn?.("voice-transcript: skipping (no runtime.subagent.run)");
      return;
    }

    const rid = data.recording_id || String(Date.now());
    if (isDuplicate(`voice-${rid}`)) {
      log?.info?.(`voice-transcript: dedup skip (${rid})`);
      return;
    }

    const settings = await getReactionSettings();
    if (!settings.voiceReactionsEnabled) {
      log?.info?.("voice-transcript: voiceReactions disabled, skipping");
      return;
    }

    const fullText = extractFullText(data);
    if (fullText.length < MIN_FIRE_CHARS) {
      log?.info?.(`voice-transcript: text too short (${fullText.length}/${MIN_FIRE_CHARS} chars), skipping`);
      return;
    }

    const wantsLine = settings.lineDeliveryEnabled;
    const wantsVibeterm = settings.vibetermDeliveryEnabled;
    if (!wantsLine && !wantsVibeterm) {
      log?.info?.("voice-transcript: no delivery channels enabled, skipping");
      return;
    }

    const eventText = buildEventText(data, settings);

    try {
      await runtime.subagent.run({
        sessionKey: "main",
        message: eventText,
        deliver: wantsLine,
        idempotencyKey: `voice-${rid}`,
      });
      log?.info?.(`voice-transcript: subagent.run sent (LINE=${wantsLine}, Vibeterm=${wantsVibeterm})`);
    } catch (err) {
      log?.warn?.(`voice-transcript: subagent.run failed: ${(err as Error).message}`);
    }
  }

  return async (req, res) => {
    if (req.method !== "POST") {
      sendError(res, 405, "METHOD_NOT_ALLOWED", "Only POST is accepted");
      return;
    }

    const clientIp = (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() || req.socket.remoteAddress || "unknown";
    if (!rateLimiter.isAllowed(clientIp)) {
      sendError(res, 429, "RATE_LIMITED", "Too many requests");
      return;
    }

    const auth = verifyAuth(req, gatewayToken);
    if (!auth.valid) {
      log?.debug?.(`voice-transcript: auth failed: ${auth.error}`);
      sendError(res, 401, "UNAUTHORIZED", auth.error!);
      return;
    }

    let body: TranscriptData;
    try {
      const raw = await readBody(req);
      body = JSON.parse(raw) as TranscriptData;
    } catch (err) {
      if (err instanceof PayloadTooLargeError) {
        sendError(res, 413, "PAYLOAD_TOO_LARGE", "Request body exceeds maximum allowed size");
        return;
      }
      sendError(res, 400, "BAD_REQUEST", "Invalid JSON body");
      return;
    }

    if (!body.event || body.event !== "recording_stored") {
      sendError(res, 400, "BAD_REQUEST", 'Expected event: "recording_stored"');
      return;
    }

    log?.info?.(
      `voice-transcript: received recording=${body.recording_id} ` +
        `duration=${body.duration_sec}s speakers=${body.speaker_count} lang=${body.language}`,
    );

    await appendDiaryEntry(body, log);
    await persistState(body, log);
    addToBuffer(body);

    await trySendChat(body);

    sendJson(res, { received: true });
  };
}
