import type { IncomingMessage, ServerResponse } from "node:http";

const MAX_BODY_BYTES = 1_048_576; // 1 MB

export class PayloadTooLargeError extends Error {
  constructor() {
    super("Request body exceeds maximum allowed size");
    this.name = "PayloadTooLargeError";
  }
}

export function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const contentLength = req.headers["content-length"];
    if (contentLength && parseInt(contentLength, 10) > MAX_BODY_BYTES) {
      req.destroy();
      reject(new PayloadTooLargeError());
      return;
    }

    const chunks: Buffer[] = [];
    let totalBytes = 0;
    req.on("data", (chunk: Buffer) => {
      totalBytes += chunk.length;
      if (totalBytes > MAX_BODY_BYTES) {
        req.destroy();
        reject(new PayloadTooLargeError());
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    req.on("error", reject);
  });
}

export function sendError(res: ServerResponse, status: number, code: string, message: string): void {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: { code, message } }));
}

export function sendJson(res: ServerResponse, data: unknown): void {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
}
