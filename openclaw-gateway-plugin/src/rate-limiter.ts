export interface RateLimiterOptions {
  maxRequests: number;
  windowMs: number;
}

export class RateLimiter {
  private readonly maxRequests: number;
  private readonly windowMs: number;
  private readonly timestamps: Map<string, number[]> = new Map();

  constructor(options: RateLimiterOptions) {
    this.maxRequests = options.maxRequests;
    this.windowMs = options.windowMs;
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
}
