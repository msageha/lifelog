import type { IncomingMessage } from "node:http";
import type { OpenClawApi, HttpHandler } from "./types.js";
import { verifyAuth } from "./auth.js";
import { getReactionSettings, saveReactionSettings } from "./recall-settings.js";
import { readBody, sendError, sendJson, PayloadTooLargeError } from "./http.js";
import { RateLimiter } from "./rate-limiter.js";

function getClientIp(req: IncomingMessage): string {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string") return forwarded.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}

export function createSettingsHandler(api: OpenClawApi): HttpHandler {
  const gatewayToken = api.config?.gateway?.auth?.token;
  if (!gatewayToken) {
    throw new Error("recall-settings: gateway auth token is required but not configured");
  }
  const log = api.logger;
  const limiter = new RateLimiter({ maxRequests: 60, windowMs: 60_000 });

  return async (req, res) => {
    const clientIp = getClientIp(req);
    if (!limiter.isAllowed(clientIp)) {
      sendError(res, 429, "TOO_MANY_REQUESTS", "Rate limit exceeded");
      return;
    }

    const auth = verifyAuth(req, gatewayToken);
    if (!auth.valid) {
      sendError(res, 401, "UNAUTHORIZED", auth.error!);
      return;
    }

    if (req.method === "GET") {
      const settings = await getReactionSettings();
      sendJson(res, settings);
      return;
    }

    if (req.method === "POST") {
      let body: Record<string, unknown>;
      try {
        const raw = await readBody(req);
        body = JSON.parse(raw) as Record<string, unknown>;
      } catch (err) {
        if (err instanceof PayloadTooLargeError) {
          sendError(res, 413, "PAYLOAD_TOO_LARGE", err.message);
          return;
        }
        sendError(res, 400, "BAD_REQUEST", "Invalid JSON body");
        return;
      }

      const saved = await saveReactionSettings(body);
      log?.info?.(`recall-settings: updated ${JSON.stringify(saved)}`);
      sendJson(res, saved);
      return;
    }

    sendError(res, 405, "METHOD_NOT_ALLOWED", "Only GET and POST are accepted");
  };
}
