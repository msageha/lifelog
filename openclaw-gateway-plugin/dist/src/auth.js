function extractBearerToken(header) {
    if (!header)
        return null;
    const match = header.match(/^Bearer\s+(\S+)$/i);
    return match ? match[1] : null;
}
export function verifyAuth(req, gatewayToken) {
    const token = extractBearerToken(req.headers.authorization);
    if (!token) {
        return { valid: false, error: "Missing or malformed Authorization header" };
    }
    if (token !== gatewayToken) {
        return { valid: false, error: "Invalid token" };
    }
    return { valid: true };
}
//# sourceMappingURL=auth.js.map