export class FileWriteQueue {
  private readonly chains = new Map<string, Promise<void>>();

  enqueue(path: string, fn: () => Promise<void>): Promise<void> {
    const prev = this.chains.get(path) ?? Promise.resolve();
    const next = prev.then(fn, () => fn());
    this.chains.set(path, next);
    return next;
  }
}
