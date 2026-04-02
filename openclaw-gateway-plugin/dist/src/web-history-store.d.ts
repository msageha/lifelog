export interface WebHistoryEntry {
    id: string;
    url: string;
    title: string;
    domain: string;
    content: string;
    visitedAt: string;
    dwellSeconds: number;
    meta: Record<string, unknown>;
    engagement?: Record<string, unknown>;
    receivedAt?: string;
    [key: string]: unknown;
}
export declare function flushSeenIds(): Promise<void>;
export declare function storeEntry(entry: WebHistoryEntry): boolean;
export declare function getLatest(): WebHistoryEntry | null;
export declare function getRecentEntries(limit?: number, maxAgeMs?: number): WebHistoryEntry[];
export declare function getStats(): {
    dedupSize: number;
    historySize: number;
    hasLatest: boolean;
    lastEntryAt: string | null;
};
//# sourceMappingURL=web-history-store.d.ts.map