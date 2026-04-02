export interface RateLimiterOptions {
  maxRequests: number;
  windowMs: number;
}

const CLEANUP_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

export class RateLimiter {
  private readonly maxRequests: number;
  private readonly windowMs: number;
  private readonly timestamps: Map<string, number[]> = new Map();
  private readonly cleanupTimer: ReturnType<typeof setInterval>;

  constructor(options: RateLimiterOptions) {
    this.maxRequests = options.maxRequests;
    this.windowMs = options.windowMs;
    this.cleanupTimer = setInterval(() => this.cleanup(), CLEANUP_INTERVAL_MS);
    this.cleanupTimer.unref?.();
  }

  isAllowed(key: string): boolean {
    const now = Date.now();
    const windowStart = now - this.windowMs;
    const recent = (this.timestamps.get(key) ?? []).filter((t) => t > windowStart);
    if (recent.length >= this.maxRequests) {
      this.timestamps.set(key, recent);
      return false;
    }
    recent.push(now);
    this.timestamps.set(key, recent);
    return true;
  }

  private cleanup(): void {
    const now = Date.now();
    const windowStart = now - this.windowMs;
    for (const [key, timestamps] of this.timestamps) {
      const recent = timestamps.filter((t) => t > windowStart);
      if (recent.length === 0) {
        this.timestamps.delete(key);
      } else {
        this.timestamps.set(key, recent);
      }
    }
  }

  dispose(): void {
    clearInterval(this.cleanupTimer);
  }
}
