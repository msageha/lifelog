const DEDUP_TTL_MS = 60 * 60 * 1000; // 1 hour
const HISTORY_MAX = 100;
const CLEANUP_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

export interface LocationSample {
  id: string;
  lat: number;
  lon: number;
  accuracy?: number;
  altitude?: number;
  speed?: number;
  bearing?: number;
  timestamp?: string;
  receivedAt?: string;
  [key: string]: unknown;
}

export interface HealthSummary {
  steps?: number;
  heartRateAvg?: number;
  heartRateMin?: number;
  heartRateMax?: number;
  restingHeartRate?: number;
  hrvAvgMs?: number;
  activeEnergyKcal?: number;
  distanceMeters?: number;
  bloodOxygenPercent?: number;
  respiratoryRateAvg?: number;
  bodyTemperatureCelsius?: number;
  wristTemperatureCelsius?: number;
  bodyMassKg?: number;
  sleepMinutes?: {
    total?: number;
    deep?: number;
    rem?: number;
    core?: number;
    awake?: number;
  };
  workouts?: Array<{
    activityType: string;
    durationSeconds?: number;
    energyKcal?: number;
  }>;
  receivedAt?: string;
  [key: string]: unknown;
}

export interface MotionActivity {
  activity?: string;
  confidence?: string;
  timestamp?: string;
  receivedAt?: string;
  [key: string]: unknown;
}

export interface NowPlaying {
  title?: string;
  artist?: string;
  album?: string;
  timestamp?: string;
  receivedAt?: string;
  [key: string]: unknown;
}

const seenIds = new Map<string, number>();
const history: LocationSample[] = [];

let latestLocation: LocationSample | null = null;
let latestHealth: HealthSummary | null = null;
let latestMotion: MotionActivity | null = null;
let latestNowPlaying: NowPlaying | null = null;

let lastLocationNewAt: string | null = null;
let lastHealthAt: string | null = null;

// Periodic cleanup of expired dedup entries
setInterval(() => {
  const cutoff = Date.now() - DEDUP_TTL_MS;
  for (const [id, ts] of seenIds) {
    if (ts < cutoff) seenIds.delete(id);
  }
}, CLEANUP_INTERVAL_MS);

export function isDuplicate(id: string): boolean {
  if (!id) return false;
  return seenIds.has(id);
}

export function storeSample(sample: LocationSample): boolean {
  if (!sample.id) return false;
  if (seenIds.has(sample.id)) return false;

  seenIds.set(sample.id, Date.now());

  const entry: LocationSample = {
    ...sample,
    receivedAt: new Date().toISOString(),
  };

  history.push(entry);
  if (history.length > HISTORY_MAX) {
    history.shift();
  }

  latestLocation = entry;
  lastLocationNewAt = entry.receivedAt!;
  (globalThis as Record<string, unknown>).__recallLatestLocation = entry;
  return true;
}

export function getLatest(): LocationSample | null {
  return latestLocation;
}

export function getHistory(limit = 10): LocationSample[] {
  return history.slice(-limit);
}

export function storeHealth(summary: HealthSummary): boolean {
  const entry: HealthSummary = {
    ...summary,
    receivedAt: new Date().toISOString(),
  };
  latestHealth = entry;
  lastHealthAt = entry.receivedAt!;
  (globalThis as Record<string, unknown>).__recallLatestHealth = entry;
  return true;
}

export function getLatestHealth(): HealthSummary | null {
  return latestHealth;
}

export function storeMotion(motion: MotionActivity): void {
  latestMotion = { ...motion, receivedAt: new Date().toISOString() };
  (globalThis as Record<string, unknown>).__recallLatestMotion = latestMotion;
}

export function getLatestMotion(): MotionActivity | null {
  return latestMotion;
}

export function storeNowPlaying(nowPlaying: NowPlaying): void {
  latestNowPlaying = { ...nowPlaying, receivedAt: new Date().toISOString() };
  (globalThis as Record<string, unknown>).__recallLatestNowPlaying = latestNowPlaying;
}

export function getLatestNowPlaying(): NowPlaying | null {
  return latestNowPlaying;
}

export function getStats(): {
  dedupSize: number;
  historySize: number;
  hasLatest: boolean;
  hasHealth: boolean;
} {
  return {
    dedupSize: seenIds.size,
    historySize: history.length,
    hasLatest: latestLocation !== null,
    hasHealth: latestHealth !== null,
  };
}

export function getLastSuccessTimes(): {
  lastLocationNewAt: string | null;
  lastHealthAt: string | null;
} {
  return {
    lastLocationNewAt,
    lastHealthAt,
  };
}
