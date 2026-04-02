import type { OpenClawPlugin } from "./src/types.js";
import { createTelemetryHandler } from "./src/handler.js";
import { createSettingsHandler } from "./src/settings-handler.js";
import { createVoiceTranscriptHandler } from "./src/voice-transcript-handler.js";
import { createWebHistoryHandler } from "./src/web-history-handler.js";

const plugin: OpenClawPlugin = {
  id: "lifelog-gateway",
  name: "Lifelog Gateway",
  description: "REST endpoints for lifelog telemetry, web history, and voice transcript ingestion",

  configSchema: {
    type: "object",
    additionalProperties: false,
    properties: {},
  },

  register(api) {
    const telemetryHandler = createTelemetryHandler(api);
    const webHistoryHandler = createWebHistoryHandler(api);
    const settingsHandler = createSettingsHandler(api);
    const voiceTranscriptHandler = createVoiceTranscriptHandler(api);

    api.registerHttpRoute({
      path: "/api/telemetry",
      handler: telemetryHandler,
      auth: "gateway",
    });
    api.logger?.info?.("lifelog-gateway: registered POST /api/telemetry");

    api.registerHttpRoute({
      path: "/api/web-history",
      handler: webHistoryHandler,
      auth: "gateway",
    });
    api.logger?.info?.("lifelog-gateway: registered POST /api/web-history");

    api.registerHttpRoute({
      path: "/api/recall-settings",
      handler: settingsHandler,
      auth: "gateway",
    });
    api.logger?.info?.("lifelog-gateway: registered GET/POST /api/recall-settings");

    api.registerHttpRoute({
      path: "/api/voice-transcript",
      handler: voiceTranscriptHandler,
      auth: "gateway",
    });
    api.logger?.info?.("lifelog-gateway: registered POST /api/voice-transcript");
  },
};

export default plugin;
