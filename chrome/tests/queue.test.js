// Set up fake IndexedDB before importing queue.js
// (queue.js lazily opens the DB on first call, so setting globals here is sufficient)
import "fake-indexeddb/auto";
import { describe, it, expect, beforeEach } from "@jest/globals";
import { enqueue, dequeueAll, count } from "../lib/queue.js";

async function clearQueue() {
  await dequeueAll();
}

describe("queue - FIFO operations", () => {
  beforeEach(async () => {
    await clearQueue();
  });

  it("dequeueAll returns entries in insertion order (FIFO)", async () => {
    await enqueue({ url: "https://first.com" });
    await enqueue({ url: "https://second.com" });
    await enqueue({ url: "https://third.com" });

    const entries = await dequeueAll();
    expect(entries).toHaveLength(3);
    expect(entries[0].url).toBe("https://first.com");
    expect(entries[1].url).toBe("https://second.com");
    expect(entries[2].url).toBe("https://third.com");
  });

  it("enqueue stores an entry and count reflects it", async () => {
    await enqueue({ url: "https://example.com" });
    expect(await count()).toBe(1);
  });

  it("dequeueAll clears the store", async () => {
    await enqueue({ url: "https://example.com" });
    await dequeueAll();
    expect(await count()).toBe(0);
  });

  it("dequeueAll returns the entry data", async () => {
    const entry = { url: "https://example.com", title: "Example", duration: 42 };
    await enqueue(entry);
    const results = await dequeueAll();
    expect(results).toHaveLength(1);
    expect(results[0]).toEqual(entry);
  });

  it("multiple enqueues accumulate entries", async () => {
    await enqueue({ url: "https://a.com" });
    await enqueue({ url: "https://b.com" });
    expect(await count()).toBe(2);
  });
});

describe("queue - empty queue behavior", () => {
  beforeEach(async () => {
    await clearQueue();
  });

  it("dequeueAll on empty queue returns empty array", async () => {
    const results = await dequeueAll();
    expect(results).toEqual([]);
  });

  it("count on empty queue returns 0", async () => {
    expect(await count()).toBe(0);
  });

  it("dequeueAll is idempotent when called multiple times on empty queue", async () => {
    const r1 = await dequeueAll();
    const r2 = await dequeueAll();
    expect(r1).toEqual([]);
    expect(r2).toEqual([]);
  });
});

describe("queue - max entries (1000 limit)", () => {
  beforeEach(async () => {
    await clearQueue();
  });

  it("count does not exceed 1000 after inserting 1050 entries", async () => {
    for (let i = 0; i < 1050; i++) {
      await enqueue({ url: `https://example.com/page/${i}`, index: i });
    }
    const total = await count();
    expect(total).toBeLessThanOrEqual(1000);
  });

  it("most recent entries are kept when over limit", async () => {
    for (let i = 0; i < 1010; i++) {
      await enqueue({ url: `https://example.com/page/${i}`, index: i });
    }
    const entries = await dequeueAll();
    expect(entries.length).toBeLessThanOrEqual(1000);
    // The most recent entry (index 1009) should be present
    const indices = entries.map((e) => e.index);
    expect(indices).toContain(1009);
  });

  it("count is exactly 1000 after 1001 enqueues", async () => {
    for (let i = 0; i < 1001; i++) {
      await enqueue({ url: `https://example.com/${i}` });
    }
    expect(await count()).toBe(1000);
  });
}, 60000);
