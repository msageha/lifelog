import type { IncomingMessage } from "node:http";
export declare function verifyAuth(req: IncomingMessage, gatewayToken: string): {
    valid: boolean;
    error?: string;
};
//# sourceMappingURL=auth.d.ts.map