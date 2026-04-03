import { promises as fs } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { IncomingMessage } from "node:http";
import type { OpenClawApi, HttpHandler, OpenClawLogger } from "./types.js";
import { verifyAuth } from "./auth.js";
import { RateLimiter } from "./rate-limiter.js";
import {
  getLastSuccessTimes,
  storeHealth,
  storeMotion,
  storeNowPlaying,
  storeSample,
} from "./store.js";
import type { HealthSummary, LocationSample, MotionActivity, NowPlaying } from "./store.js";
import { readBody, sendError, sendJson, PayloadTooLargeError } from "./http.js";
import { FileWriteQueue } from "./file-write-queue.js";

const NEXT_MIN_INTERVAL_SEC = 60;

const LOCATION_AGG_WINDOW_MS = 30 * 60 * 1000;
const LOCATION_DEDUP_EPS = 0.0001;
const LOCATION_MIN_WRITE_DISTANCE_M = 200;
const LOCATION_MIN_WRITE_DURATION_MS = 30 * 60 * 1000;

const MEMORY_ROOT = join(homedir(), ".openclaw", "workspace", "memory");
const CURRENT_LOCATION_PATH = join(MEMORY_ROOT, "current-location.json");
const HEALTH_STATE_PATH = join(MEMORY_ROOT, "health-state.json");
const MOTION_STATE_PATH = join(MEMORY_ROOT, "motion-state.json");
const NOW_PLAYING_STATE_PATH = join(MEMORY_ROOT, "now-playing-state.json");

const fileWriteQueue = new FileWriteQueue();

function getClientIp(req: IncomingMessage): string {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string") return forwarded.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}

interface AggPoint {
  lat: number;
  lon: number;
  accuracy?: number;
  ts: Date;
}

interface AggWindow {
  dateStr: string;
  start: Date;
  end: Date;
  samples: AggPoint[];
}

let locationAggWindow: AggWindow | null = null;

function haversineM(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
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

function isSameApproxPoint(a: AggPoint, b: AggPoint): boolean {
  return Math.abs(a.lat - b.lat) <= LOCATION_DEDUP_EPS && Math.abs(a.lon - b.lon) <= LOCATION_DEDUP_EPS;
}

function createWindow(ts: Date): AggWindow {
  const startMs = Math.floor(ts.getTime() / LOCATION_AGG_WINDOW_MS) * LOCATION_AGG_WINDOW_MS;
  const start = new Date(startMs);
  return {
    dateStr: formatJstDate(ts),
    start,
    end: new Date(startMs + LOCATION_AGG_WINDOW_MS),
    samples: [],
  };
}

async function flushLocationAggWindow(log: OpenClawLogger | undefined): Promise<void> {
  if (!locationAggWindow || locationAggWindow.samples.length === 0) {
    return;
  }

  const samples = [...locationAggWindow.samples].sort((a, b) => a.ts.getTime() - b.ts.getTime());
  const deduped: AggPoint[] = [];
  for (const sample of samples) {
    const prev = deduped[deduped.length - 1];
    if (!prev || !isSameApproxPoint(prev, sample)) {
      deduped.push(sample);
    }
  }

  if (deduped.length === 0) {
    locationAggWindow = null;
    return;
  }

  let distanceM = 0;
  for (let i = 1; i < deduped.length; i++) {
    distanceM += haversineM(deduped[i - 1].lat, deduped[i - 1].lon, deduped[i].lat, deduped[i].lon);
  }

  const durationMs = deduped[deduped.length - 1].ts.getTime() - deduped[0].ts.getTime();
  if (distanceM < LOCATION_MIN_WRITE_DISTANCE_M && durationMs < LOCATION_MIN_WRITE_DURATION_MS) {
    locationAggWindow = null;
    return;
  }

  const first = deduped[0];
  const last = deduped[deduped.length - 1];
  const accValues = deduped
    .map((s) => (typeof s.accuracy === "number" ? s.accuracy : null))
    .filter((v): v is number => v != null);
  const avgAcc = accValues.length ? Math.round(accValues.reduce((a, b) => a + b, 0) / accValues.length) : "?";

  const timeRange = `${formatJstTime(first.ts)}-${formatJstTime(last.ts)}`;
  const line = `\u{1F4CD} ${timeRange} 集計: ${samples.length}件/ユニーク${deduped.length}点 | 移動 ${(distanceM / 1000).toFixed(1)}km | 最終 ${last.lat.toFixed(4)}, ${last.lon.toFixed(4)} (avg acc ${avgAcc}m)\n`;

  const diaryPath = join(MEMORY_ROOT, `${locationAggWindow.dateStr}.md`);

  try {
    await fileWriteQueue.enqueue(diaryPath, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.appendFile(diaryPath, line, { encoding: "utf-8", mode: 0o600 });
    });
    log?.debug?.(`recall-telemetry: location aggregated diary entry written to ${locationAggWindow.dateStr}.md`);
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to write aggregated diary: ${(err as Error).message}`);
  } finally {
    locationAggWindow = null;
  }
}

async function maybeWriteDiary(sample: LocationSample, log: OpenClawLogger | undefined): Promise<void> {
  const ts = sample.timestamp ? new Date(sample.timestamp) : new Date();
  if (Number.isNaN(ts.getTime())) return;

  if (!locationAggWindow) {
    locationAggWindow = createWindow(ts);
  }

  const sampleDate = formatJstDate(ts);
  const outOfWindow = ts < locationAggWindow.start || ts >= locationAggWindow.end;
  const crossDay = sampleDate !== locationAggWindow.dateStr;
  if (outOfWindow || crossDay) {
    await flushLocationAggWindow(log);
    locationAggWindow = createWindow(ts);
  }

  if (typeof sample.lat !== "number" || typeof sample.lon !== "number") return;
  locationAggWindow.samples.push({
    lat: sample.lat,
    lon: sample.lon,
    accuracy: sample.accuracy,
    ts,
  });
}

// Health diary throttle state
let lastHealthDiaryWrite = 0;
const HEALTH_DIARY_TIME_THRESHOLD_MS = 30 * 60 * 1000; // 30 minutes

async function maybeWriteHealthDiary(health: HealthSummary, log: OpenClawLogger | undefined): Promise<void> {
  const now = new Date();
  if (now.getTime() - lastHealthDiaryWrite < HEALTH_DIARY_TIME_THRESHOLD_MS) {
    return;
  }
  const timeStr = formatJstTime(now);
  const dateStr = formatJstDate(now);

  const parts: string[] = [];
  if (health.steps != null) parts.push(`${health.steps} steps`);
  if (health.activeEnergyKcal != null) parts.push(`${Math.round(health.activeEnergyKcal)}kcal`);
  if (health.distanceMeters != null) parts.push(`${(health.distanceMeters / 1000).toFixed(1)}km`);
  if (health.heartRateAvg != null) {
    let hr = `HR ${Math.round(health.heartRateAvg)}`;
    if (health.heartRateMin != null && health.heartRateMax != null) {
      hr += ` (${Math.round(health.heartRateMin)}-${Math.round(health.heartRateMax)})`;
    }
    hr += "bpm";
    parts.push(hr);
  }
  if (health.restingHeartRate != null) parts.push(`RHR ${Math.round(health.restingHeartRate)}bpm`);
  if (health.hrvAvgMs != null) parts.push(`HRV ${Math.round(health.hrvAvgMs)}ms`);
  if (health.bloodOxygenPercent != null) parts.push(`SpO2 ${Math.round(health.bloodOxygenPercent)}%`);
  if (health.respiratoryRateAvg != null) parts.push(`resp ${health.respiratoryRateAvg.toFixed(1)}/min`);
  if (health.bodyTemperatureCelsius != null) parts.push(`temp ${health.bodyTemperatureCelsius.toFixed(1)}C`);
  if (health.wristTemperatureCelsius != null) parts.push(`wrist ${health.wristTemperatureCelsius.toFixed(1)}C`);
  if (health.bodyMassKg != null) parts.push(`${health.bodyMassKg.toFixed(1)}kg`);
  if (health.sleepMinutes?.total != null) {
    let sleep = `sleep ${(health.sleepMinutes.total / 60).toFixed(1)}h`;
    const stages: string[] = [];
    if (health.sleepMinutes.deep != null) stages.push(`deep ${Math.round(health.sleepMinutes.deep)}m`);
    if (health.sleepMinutes.rem != null) stages.push(`REM ${Math.round(health.sleepMinutes.rem)}m`);
    if (health.sleepMinutes.core != null) stages.push(`core ${Math.round(health.sleepMinutes.core)}m`);
    if (health.sleepMinutes.awake != null) stages.push(`awake ${Math.round(health.sleepMinutes.awake)}m`);
    if (stages.length > 0) sleep += ` (${stages.join(", ")})`;
    parts.push(sleep);
  }
  if (health.workouts?.length) {
    const wo = health.workouts.map((w) => {
      let s = w.activityType;
      if (w.durationSeconds) s += ` ${Math.round(w.durationSeconds / 60)}min`;
      if (w.energyKcal) s += ` ${Math.round(w.energyKcal)}kcal`;
      return s;
    });
    parts.push(`workouts: ${wo.join(", ")}`);
  }

  if (parts.length === 0) return;

  const line = `\u{2764}\u{FE0F} ${timeStr} - ${parts.join(" | ")}\n`;
  const diaryPath = join(MEMORY_ROOT, `${dateStr}.md`);

  try {
    await fileWriteQueue.enqueue(diaryPath, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.appendFile(diaryPath, line, { encoding: "utf-8", mode: 0o600 });
    });
    lastHealthDiaryWrite = now.getTime();
    log?.debug?.(`recall-telemetry: health diary entry written to ${dateStr}.md`);
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to write health diary: ${(err as Error).message}`);
  }
}

async function persistCurrentLocation(sample: LocationSample, log: OpenClawLogger | undefined): Promise<void> {
  const now = new Date();
  const state = {
    lat: sample.lat,
    lon: sample.lon,
    accuracy: sample.accuracy,
    altitude: sample.altitude,
    speed: sample.speed,
    timestamp: sample.timestamp,
    updatedAt: now.toISOString(),
    source: "recall-telemetry",
  };
  try {
    await fileWriteQueue.enqueue(CURRENT_LOCATION_PATH, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.writeFile(CURRENT_LOCATION_PATH, JSON.stringify(state, null, 2), { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to persist current-location.json: ${(err as Error).message}`);
  }
}

async function persistHealthState(health: HealthSummary, log: OpenClawLogger | undefined): Promise<void> {
  const now = new Date();
  const state = {
    ...health,
    updatedAt: now.toISOString(),
    receivedAt: now.toISOString(),
    source: "recall-telemetry",
  };
  try {
    await fileWriteQueue.enqueue(HEALTH_STATE_PATH, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.writeFile(HEALTH_STATE_PATH, JSON.stringify(state, null, 2), { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to persist health-state.json: ${(err as Error).message}`);
  }
}

async function persistMotionState(motion: MotionActivity, log: OpenClawLogger | undefined): Promise<void> {
  const now = new Date();
  const state = {
    ...motion,
    updatedAt: now.toISOString(),
    receivedAt: now.toISOString(),
    source: "recall-telemetry",
  };
  try {
    await fileWriteQueue.enqueue(MOTION_STATE_PATH, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.writeFile(MOTION_STATE_PATH, JSON.stringify(state, null, 2), { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to persist motion-state.json: ${(err as Error).message}`);
  }
}

async function persistNowPlayingState(nowPlaying: NowPlaying, log: OpenClawLogger | undefined): Promise<void> {
  const now = new Date();
  const state = {
    ...nowPlaying,
    updatedAt: now.toISOString(),
    receivedAt: now.toISOString(),
    source: "recall-telemetry",
  };
  try {
    await fileWriteQueue.enqueue(NOW_PLAYING_STATE_PATH, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.writeFile(NOW_PLAYING_STATE_PATH, JSON.stringify(state, null, 2), { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to persist now-playing-state.json: ${(err as Error).message}`);
  }
}

// Motion/NowPlaying diary throttle state
let lastMotionDiaryActivity: string | null = null;
let lastNowPlayingDiaryTitle: string | null = null;

async function maybeWriteMotionDiary(motion: MotionActivity, log: OpenClawLogger | undefined): Promise<void> {
  if (!motion.activity || motion.activity === lastMotionDiaryActivity) return;
  lastMotionDiaryActivity = motion.activity;

  const now = new Date();
  const timeStr = formatJstTime(now);
  const dateStr = formatJstDate(now);
  const conf = motion.confidence || "?";
  const line = `\u{1F6B6} ${timeStr} Motion: ${motion.activity} (${conf})\n`;

  const diaryPath = join(MEMORY_ROOT, `${dateStr}.md`);
  try {
    await fileWriteQueue.enqueue(diaryPath, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.appendFile(diaryPath, line, { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to write motion diary: ${(err as Error).message}`);
  }
}

async function maybeWriteNowPlayingDiary(nowPlaying: NowPlaying, log: OpenClawLogger | undefined): Promise<void> {
  const title = nowPlaying.title;
  if (!title || title === lastNowPlayingDiaryTitle) return;
  lastNowPlayingDiaryTitle = title;

  const now = new Date();
  const timeStr = formatJstTime(now);
  const dateStr = formatJstDate(now);
  const artist = nowPlaying.artist || "?";
  const line = `\u{1F3B5} ${timeStr} Now Playing: ${title} — ${artist}\n`;

  const diaryPath = join(MEMORY_ROOT, `${dateStr}.md`);
  try {
    await fileWriteQueue.enqueue(diaryPath, async () => {
      await fs.mkdir(MEMORY_ROOT, { recursive: true, mode: 0o700 });
      await fs.appendFile(diaryPath, line, { encoding: "utf-8", mode: 0o600 });
    });
  } catch (err) {
    log?.warn?.(`recall-telemetry: failed to write now playing diary: ${(err as Error).message}`);
  }
}

interface TelemetryEvent {
  type: string;
  id: string;
  timestamp?: string;
  data?: Record<string, unknown>;
}

interface TelemetryBody {
  events?: TelemetryEvent[];
  samples?: Array<Record<string, unknown>>;
  health?: HealthSummary;
  motion?: MotionActivity;
  nowPlaying?: NowPlaying;
}

export function createTelemetryHandler(api: OpenClawApi): HttpHandler {
  const gatewayToken = api.config?.gateway?.auth?.token;
  if (!gatewayToken) {
    throw new Error("recall-telemetry: gateway auth token is required but not configured");
  }
  const log = api.logger;
  const rateLimiter = new RateLimiter({ maxRequests: 120, windowMs: 60_000 });

  return async (req, res) => {
    if (req.method !== "POST") {
      sendError(res, 405, "METHOD_NOT_ALLOWED", "Only POST is accepted");
      return;
    }

    const clientIp = getClientIp(req);
    if (!rateLimiter.isAllowed(clientIp)) {
      sendError(res, 429, "RATE_LIMITED", "Too many requests");
      return;
    }

    const auth = verifyAuth(req, gatewayToken);
    if (!auth.valid) {
      log?.debug?.(`recall-telemetry: auth failed: ${auth.error}`);
      sendError(res, 401, "UNAUTHORIZED", auth.error!);
      return;
    }

    let body: TelemetryBody;
    try {
      const raw = await readBody(req);
      body = JSON.parse(raw) as TelemetryBody;
    } catch (err) {
      if (err instanceof PayloadTooLargeError) {
        sendError(res, 413, "PAYLOAD_TOO_LARGE", "Request body exceeds maximum allowed size");
        return;
      }
      sendError(res, 400, "BAD_REQUEST", "Invalid JSON body");
      return;
    }

    let events: TelemetryEvent[];
    if (Array.isArray(body.events)) {
      events = body.events;
    } else if (Array.isArray(body.samples)) {
      events = body.samples.map((s) => ({
        type: "location",
        id: s.id as string,
        timestamp: s.timestamp as string | undefined,
        data: {
          lat: s.lat,
          lon: s.lon,
          accuracy: s.accuracy,
          altitude: s.altitude,
          speed: s.speed,
        } as Record<string, unknown>,
      }));
    } else if (body.health && typeof body.health === "object") {
      events = [];
    } else {
      sendError(res, 400, "BAD_REQUEST", '"events", "samples", or "health" payload is required');
      return;
    }

    let received = 0;
    for (const event of events) {
      if (!event.id || !event.type) continue;

      switch (event.type) {
        case "location": {
          const sample: LocationSample = {
            id: event.id,
            ...(event.data as { lat: number; lon: number; accuracy?: number; altitude?: number; speed?: number }),
            timestamp: event.timestamp,
          };
          if (typeof sample.lat !== "number" || typeof sample.lon !== "number") {
            log?.debug?.(`recall-telemetry: skipping invalid location event: ${JSON.stringify(event).slice(0, 100)}`);
            break;
          }
          if (storeSample(sample)) {
            received++;
            maybeWriteDiary(sample, log).catch(() => {});
            persistCurrentLocation(sample, log).catch(() => {});
          }
          break;
        }
        default:
          log?.debug?.(`recall-telemetry: unknown event type "${event.type}", skipping`);
      }
    }

    let healthReceived = false;
    if (body.health && typeof body.health === "object") {
      storeHealth(body.health);
      healthReceived = true;
      maybeWriteHealthDiary(body.health, log).catch(() => {});
      persistHealthState(body.health, log).catch(() => {});
    }

    let motionReceived = false;
    if (body.motion && typeof body.motion === "object") {
      storeMotion(body.motion);
      motionReceived = true;
      persistMotionState(body.motion, log).catch(() => {});
      maybeWriteMotionDiary(body.motion, log).catch(() => {});
    }

    let nowPlayingReceived = false;
    if (body.nowPlaying && typeof body.nowPlaying === "object") {
      storeNowPlaying(body.nowPlaying);
      nowPlayingReceived = true;
      persistNowPlayingState(body.nowPlaying, log).catch(() => {});
      maybeWriteNowPlayingDiary(body.nowPlaying, log).catch(() => {});
    }

    const { lastLocationNewAt, lastHealthAt } = getLastSuccessTimes();
    const extras = [
      healthReceived ? "health" : null,
      motionReceived ? `motion(${body.motion?.activity})` : null,
      nowPlayingReceived ? `media(${body.nowPlaying?.title?.slice(0, 20)})` : null,
    ]
      .filter(Boolean)
      .join(", ");
    log?.info?.(
      `recall-telemetry: httpAccepted=true locationNew=${received}${extras ? ` ${extras}` : ""}` +
        ` lastLocationNewAt=${lastLocationNewAt ?? "-"} lastHealthAt=${lastHealthAt ?? "-"}`,
    );

    sendJson(res, {
      received,
      healthReceived,
      motionReceived,
      nowPlayingReceived,
      nextMinIntervalSec: NEXT_MIN_INTERVAL_SEC,
    });
  };
}
