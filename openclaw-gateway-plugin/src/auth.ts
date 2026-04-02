import type { IncomingMessage } from "node:http";
import { timingSafeEqual } from "node:crypto";

function extractBearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const match = header.match(/^Bearer\s+(\S+)$/i);
  return match ? match[1] : null;
}

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, "utf-8");
  const bufB = Buffer.from(b, "utf-8");
  if (bufA.length !== bufB.length) {
    // Compare against self to keep constant-time behavior, then return false
    timingSafeEqual(bufA, bufA);
    return false;
  }
  return timingSafeEqual(bufA, bufB);
}

export function verifyAuth(
  req: IncomingMessage,
  gatewayToken: string,
): { valid: boolean; error?: string } {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    return { valid: false, error: "Missing or malformed Authorization header" };
  }
  if (!safeEqual(token, gatewayToken)) {
    return { valid: false, error: "Invalid token" };
  }
  return { valid: true };
}
