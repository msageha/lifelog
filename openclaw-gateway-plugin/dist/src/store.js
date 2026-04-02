const DEDUP_TTL_MS = 60 * 60 * 1000; // 1 hour
const HISTORY_MAX = 100;
const CLEANUP_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes
const seenIds = new Map();
const history = [];
let latestLocation = null;
let latestHealth = null;
let latestMotion = null;
let latestNowPlaying = null;
let lastLocationNewAt = null;
let lastHealthAt = null;
// Periodic cleanup of expired dedup entries
setInterval(() => {
    const cutoff = Date.now() - DEDUP_TTL_MS;
    for (const [id, ts] of seenIds) {
        if (ts < cutoff)
            seenIds.delete(id);
    }
}, CLEANUP_INTERVAL_MS);
export function isDuplicate(id) {
    if (!id)
        return false;
    return seenIds.has(id);
}
export function storeSample(sample) {
    if (!sample.id)
        return false;
    if (seenIds.has(sample.id))
        return false;
    seenIds.set(sample.id, Date.now());
    const entry = {
        ...sample,
        receivedAt: new Date().toISOString(),
    };
    history.push(entry);
    if (history.length > HISTORY_MAX) {
        history.shift();
    }
    latestLocation = entry;
    lastLocationNewAt = entry.receivedAt;
    globalThis.__recallLatestLocation = entry;
    return true;
}
export function getLatest() {
    return latestLocation;
}
export function getHistory(limit = 10) {
    return history.slice(-limit);
}
export function storeHealth(summary) {
    const entry = {
        ...summary,
        receivedAt: new Date().toISOString(),
    };
    latestHealth = entry;
    lastHealthAt = entry.receivedAt;
    globalThis.__recallLatestHealth = entry;
    return true;
}
export function getLatestHealth() {
    return latestHealth;
}
export function storeMotion(motion) {
    latestMotion = { ...motion, receivedAt: new Date().toISOString() };
    globalThis.__recallLatestMotion = latestMotion;
}
export function getLatestMotion() {
    return latestMotion;
}
export function storeNowPlaying(nowPlaying) {
    latestNowPlaying = { ...nowPlaying, receivedAt: new Date().toISOString() };
    globalThis.__recallLatestNowPlaying = latestNowPlaying;
}
export function getLatestNowPlaying() {
    return latestNowPlaying;
}
export function getStats() {
    return {
        dedupSize: seenIds.size,
        historySize: history.length,
        hasLatest: latestLocation !== null,
        hasHealth: latestHealth !== null,
    };
}
export function getLastSuccessTimes() {
    return {
        lastLocationNewAt,
        lastHealthAt,
    };
}
//# sourceMappingURL=store.js.map