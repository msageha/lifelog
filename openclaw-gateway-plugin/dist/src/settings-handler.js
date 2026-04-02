import { verifyAuth } from "./auth.js";
import { getReactionSettings, saveReactionSettings } from "./recall-settings.js";
import { readBody, sendError, sendJson } from "./http.js";
export function createSettingsHandler(api) {
    const gatewayToken = api.config?.gateway?.auth?.token;
    const log = api.logger;
    return async (req, res) => {
        if (gatewayToken) {
            const auth = verifyAuth(req, gatewayToken);
            if (!auth.valid) {
                sendError(res, 401, "UNAUTHORIZED", auth.error);
                return;
            }
        }
        if (req.method === "GET") {
            const settings = await getReactionSettings();
            sendJson(res, settings);
            return;
        }
        if (req.method === "POST") {
            let body;
            try {
                const raw = await readBody(req);
                body = JSON.parse(raw);
            }
            catch {
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
//# sourceMappingURL=settings-handler.js.map