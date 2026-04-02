import type { IncomingMessage } from "node:http";
import { timingSafeEqual } from "node:crypto";

function extractBearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const match = header.match(/^Bearer\s+(\S+)$/i);
  return match ? match[1] : null;
}

export function verifyAuth(
  req: IncomingMessage,
  gatewayToken: string,
): { valid: boolean; error?: string } {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    return { valid: false, error: "Missing or malformed Authorization header" };
  }
  const a = Buffer.from(token, "utf-8");
  const b = Buffer.from(gatewayToken, "utf-8");
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    return { valid: false, error: "Invalid token" };
  }
  return { valid: true };
}
