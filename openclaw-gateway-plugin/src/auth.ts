import type { IncomingMessage } from "node:http";

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
  if (token !== gatewayToken) {
    return { valid: false, error: "Invalid token" };
  }
  return { valid: true };
}
