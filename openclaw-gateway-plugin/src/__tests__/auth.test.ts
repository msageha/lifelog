import type { IncomingMessage } from "node:http";
import { verifyAuth } from "../auth.js";

function mockReq(authHeader?: string): IncomingMessage {
  return {
    headers: { authorization: authHeader },
  } as unknown as IncomingMessage;
}

const VALID_TOKEN = "secret-token-123";

describe("verifyAuth", () => {
  describe("normal cases", () => {
    it("accepts a valid Bearer token", () => {
      const result = verifyAuth(mockReq(`Bearer ${VALID_TOKEN}`), VALID_TOKEN);
      expect(result).toEqual({ valid: true });
    });

    it("accepts Bearer token with lowercase 'bearer'", () => {
      const result = verifyAuth(mockReq(`bearer ${VALID_TOKEN}`), VALID_TOKEN);
      expect(result).toEqual({ valid: true });
    });

    it("accepts Bearer token with uppercase 'BEARER'", () => {
      const result = verifyAuth(mockReq(`BEARER ${VALID_TOKEN}`), VALID_TOKEN);
      expect(result).toEqual({ valid: true });
    });

    it("extracts token correctly from 'Bearer abc123' format", () => {
      const result = verifyAuth(mockReq("Bearer abc123"), "abc123");
      expect(result.valid).toBe(true);
    });
  });

  describe("error cases", () => {
    it("rejects when Authorization header is missing", () => {
      const result = verifyAuth(mockReq(undefined), VALID_TOKEN);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Missing or malformed Authorization header");
    });

    it("rejects empty Authorization header", () => {
      const result = verifyAuth(mockReq(""), VALID_TOKEN);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Missing or malformed Authorization header");
    });

    it("rejects Basic auth scheme", () => {
      const result = verifyAuth(mockReq("Basic dXNlcjpwYXNz"), VALID_TOKEN);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Missing or malformed Authorization header");
    });

    it("rejects Bearer without token value", () => {
      const result = verifyAuth(mockReq("Bearer"), VALID_TOKEN);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Missing or malformed Authorization header");
    });

    it("rejects wrong token value", () => {
      const result = verifyAuth(mockReq("Bearer wrong-token"), VALID_TOKEN);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Invalid token");
    });
  });
});
