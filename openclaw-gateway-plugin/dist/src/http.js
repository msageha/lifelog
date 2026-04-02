export function readBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        req.on("data", (chunk) => chunks.push(chunk));
        req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
        req.on("error", reject);
    });
}
export function sendError(res, status, code, message) {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: { code, message } }));
}
export function sendJson(res, data) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
}
//# sourceMappingURL=http.js.map