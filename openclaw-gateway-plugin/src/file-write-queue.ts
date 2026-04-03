export class FileWriteQueue {
  private readonly queues = new Map<string, Promise<void>>();

  async enqueue(filePath: string, writeFn: () => Promise<void>): Promise<void> {
    const prev = this.queues.get(filePath) ?? Promise.resolve();
    const next = prev.then(writeFn, () => writeFn());
    this.queues.set(filePath, next);
    try {
      await next;
    } finally {
      if (this.queues.get(filePath) === next) {
        this.queues.delete(filePath);
      }
    }
  }
}
