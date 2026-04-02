import { promises as fs } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MEMORY_ROOT = join(homedir(), ".openclaw", "workspace", "memory");
const SEEN_IDS_PATH = join(MEMORY_ROOT, "web-history-seen.json");

const DEDUP_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const HISTORY_MAX = 100;
const PERSISTED_MAX = 2000;
const CLEANUP_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

export interface WebHistoryEntry {
  id: string;
  url: string;
  title: string;
  domain: string;
  content: string;
  visitedAt: string;
  dwellSeconds: number;
  meta: Record<string, unknown>;
  engagement?: Record<string, unknown>;
  receivedAt?: string;
  [key: string]: unknown;
}

const seenIds = new Map<string, number>();
const history: WebHistoryEntry[] = [];

let latestEntry: WebHistoryEntry | null = null;
let lastEntryAt: string | null = null;
let persistChain = Promise.resolve();

function cleanupSeenIds(): void {
  const cutoff = Date.now() - DEDUP_TTL_MS;
  for (const [id, seenAtMs] of seenIds) {
    if (seenAtMs < cutoff) {
      seenIds.delete(id);
    }
  }

  if (seenIds.size <= PERSISTED_MAX) {
    return;
  }

  const sorted = [...seenIds.entries()].sort((a, b) => b[1] - a[1]);
  for (const [id] of sorted.slice(PERSISTED_MAX)) {
    seenIds.delete(id);
  }
}

async function loadSeenIds(): Promise<void> {
  try {
    const raw = await fs.readFile(SEEN_IDS_PATH, "utf-8");
    const parsed = JSON.parse(raw) as { entries?: Array<{ id: string; seenAt: string }> };
    const entries = Array.isArray(parsed?.entries) ? parsed.entries : [];
    const cutoff = Date.now() - DEDUP_TTL_MS;

    for (const entry of entries) {
      if (!entry || typeof entry.id !== "string" || typeof entry.seenAt !== "string") continue;
      const seenAtMs = Date.parse(entry.seenAt);
      if (!Number.isFinite(seenAtMs) || seenAtMs < cutoff) continue;
      seenIds.set(entry.id, seenAtMs);
    }

    cleanupSeenIds();
  } catch (err) {
    if ((err as NodeJS.ErrnoException)?.code !== "ENOENT") {
      console.warn(`recall-web-history: failed to load persistent dedup: ${(err as Error).message}`);
    }
  }
}

async function writeSeenIds(): Promise<void> {
  cleanupSeenIds();

  const entries = [...seenIds.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, PERSISTED_MAX)
    .map(([id, seenAtMs]) => ({
      id,
      seenAt: new Date(seenAtMs).toISOString(),
    }));

  const payload = {
    updatedAt: new Date().toISOString(),
    ttlSeconds: DEDUP_TTL_MS / 1000,
    entries,
  };

  await fs.mkdir(MEMORY_ROOT, { recursive: true });
  await fs.writeFile(SEEN_IDS_PATH, JSON.stringify(payload, null, 2), "utf-8");
}

export function flushSeenIds(): Promise<void> {
  persistChain = persistChain
    .then(() => writeSeenIds())
    .catch((err: Error) => {
      console.warn(`recall-web-history: failed to persist dedup state: ${err.message}`);
    });
  return persistChain;
}

function queueFlushSeenIds(): void {
  void flushSeenIds();
}

// Load persisted dedup state on startup (non-blocking)
loadSeenIds().catch((err: Error) => {
  console.warn(`recall-web-history: startup load failed: ${err.message}`);
});

const cleanupTimer = setInterval(() => {
  cleanupSeenIds();
  queueFlushSeenIds();
}, CLEANUP_INTERVAL_MS);
cleanupTimer.unref?.();

export function storeEntry(entry: WebHistoryEntry): boolean {
  if (!entry?.id || seenIds.has(entry.id)) return false;

  seenIds.set(entry.id, Date.now());

  const storedEntry: WebHistoryEntry = {
    ...entry,
    receivedAt: new Date().toISOString(),
  };

  history.push(storedEntry);
  if (history.length > HISTORY_MAX) {
    history.shift();
  }

  latestEntry = storedEntry;
  lastEntryAt = storedEntry.receivedAt!;
  (globalThis as Record<string, unknown>).__recallLatestWebHistory = storedEntry;
  queueFlushSeenIds();
  return true;
}

export function getLatest(): WebHistoryEntry | null {
  return latestEntry;
}

export function getRecentEntries(limit = 10, maxAgeMs = 24 * 60 * 60 * 1000): WebHistoryEntry[] {
  const cutoff = Date.now() - maxAgeMs;
  return history
    .filter((e) => {
      const ts = Date.parse(e.visitedAt || e.receivedAt!);
      return Number.isFinite(ts) && ts >= cutoff;
    })
    .slice(-limit)
    .reverse();
}

export function getStats(): {
  dedupSize: number;
  historySize: number;
  hasLatest: boolean;
  lastEntryAt: string | null;
} {
  return {
    dedupSize: seenIds.size,
    historySize: history.length,
    hasLatest: latestEntry !== null,
    lastEntryAt,
  };
}
