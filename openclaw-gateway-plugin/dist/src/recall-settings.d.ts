export interface ReactionSettings {
    webReactionsEnabled: boolean;
    voiceReactionsEnabled: boolean;
    lineDeliveryEnabled: boolean;
    vibetermDeliveryEnabled: boolean;
    webMinContentChars: number;
    updatedAt: string | null;
}
export declare function getReactionSettings(): Promise<ReactionSettings>;
export declare function saveReactionSettings(settings: Partial<ReactionSettings>): Promise<ReactionSettings>;
//# sourceMappingURL=recall-settings.d.ts.map