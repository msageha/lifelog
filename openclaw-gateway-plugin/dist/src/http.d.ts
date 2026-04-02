import type { IncomingMessage, ServerResponse } from "node:http";
export declare function readBody(req: IncomingMessage): Promise<string>;
export declare function sendError(res: ServerResponse, status: number, code: string, message: string): void;
export declare function sendJson(res: ServerResponse, data: unknown): void;
//# sourceMappingURL=http.d.ts.map