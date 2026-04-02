import type { IncomingMessage, ServerResponse } from "node:http";
export type HttpHandler = (req: IncomingMessage, res: ServerResponse) => Promise<void>;
export interface OpenClawLogger {
    info?(msg: string): void;
    warn?(msg: string): void;
    debug?(msg: string): void;
    error?(msg: string): void;
}
export interface SubagentRunOptions {
    sessionKey: string;
    message: string;
    deliver: boolean;
    idempotencyKey: string;
}
export interface OpenClawRuntime {
    subagent?: {
        run?(options: SubagentRunOptions): Promise<void>;
    };
}
export interface OpenClawApi {
    config?: {
        gateway?: {
            auth?: {
                token?: string;
            };
        };
    };
    logger?: OpenClawLogger;
    runtime?: OpenClawRuntime;
    registerHttpRoute(route: {
        path: string;
        handler: HttpHandler;
        auth: string;
    }): void;
}
export interface OpenClawPlugin {
    id: string;
    name: string;
    description: string;
    configSchema: object;
    register(api: OpenClawApi): void;
}
//# sourceMappingURL=types.d.ts.map