import { RateLimiter } from "../rate-limiter.js";

describe("RateLimiter", () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it("allows requests within window limit", () => {
    const limiter = new RateLimiter({ maxRequests: 3, windowMs: 1000 });
    expect(limiter.isAllowed("client1")).toBe(true);
    expect(limiter.isAllowed("client1")).toBe(true);
    expect(limiter.isAllowed("client1")).toBe(true);
  });

  it("denies request when maxRequests is exceeded within window", () => {
    const limiter = new RateLimiter({ maxRequests: 2, windowMs: 1000 });
    limiter.isAllowed("client1");
    limiter.isAllowed("client1");
    expect(limiter.isAllowed("client1")).toBe(false);
  });

  it("allows requests again after window resets", () => {
    const limiter = new RateLimiter({ maxRequests: 2, windowMs: 1000 });
    limiter.isAllowed("client1");
    limiter.isAllowed("client1");
    expect(limiter.isAllowed("client1")).toBe(false);

    jest.advanceTimersByTime(1001);

    expect(limiter.isAllowed("client1")).toBe(true);
  });

  it("tracks different keys independently", () => {
    const limiter = new RateLimiter({ maxRequests: 1, windowMs: 1000 });
    expect(limiter.isAllowed("clientA")).toBe(true);
    expect(limiter.isAllowed("clientB")).toBe(true);
    expect(limiter.isAllowed("clientA")).toBe(false);
    expect(limiter.isAllowed("clientB")).toBe(false);
  });
});
