export interface LocationSample {
    id: string;
    lat: number;
    lon: number;
    accuracy?: number;
    altitude?: number;
    speed?: number;
    bearing?: number;
    timestamp?: string;
    receivedAt?: string;
    [key: string]: unknown;
}
export interface HealthSummary {
    steps?: number;
    heartRateAvg?: number;
    heartRateMin?: number;
    heartRateMax?: number;
    restingHeartRate?: number;
    hrvAvgMs?: number;
    activeEnergyKcal?: number;
    distanceMeters?: number;
    bloodOxygenPercent?: number;
    respiratoryRateAvg?: number;
    bodyTemperatureCelsius?: number;
    wristTemperatureCelsius?: number;
    bodyMassKg?: number;
    sleepMinutes?: {
        total?: number;
        deep?: number;
        rem?: number;
        core?: number;
        awake?: number;
    };
    workouts?: Array<{
        activityType: string;
        durationSeconds?: number;
        energyKcal?: number;
    }>;
    receivedAt?: string;
    [key: string]: unknown;
}
export interface MotionActivity {
    activity?: string;
    confidence?: string;
    timestamp?: string;
    receivedAt?: string;
    [key: string]: unknown;
}
export interface NowPlaying {
    title?: string;
    artist?: string;
    album?: string;
    timestamp?: string;
    receivedAt?: string;
    [key: string]: unknown;
}
export declare function isDuplicate(id: string): boolean;
export declare function storeSample(sample: LocationSample): boolean;
export declare function getLatest(): LocationSample | null;
export declare function getHistory(limit?: number): LocationSample[];
export declare function storeHealth(summary: HealthSummary): boolean;
export declare function getLatestHealth(): HealthSummary | null;
export declare function storeMotion(motion: MotionActivity): void;
export declare function getLatestMotion(): MotionActivity | null;
export declare function storeNowPlaying(nowPlaying: NowPlaying): void;
export declare function getLatestNowPlaying(): NowPlaying | null;
export declare function getStats(): {
    dedupSize: number;
    historySize: number;
    hasLatest: boolean;
    hasHealth: boolean;
};
export declare function getLastSuccessTimes(): {
    lastLocationNewAt: string | null;
    lastHealthAt: string | null;
};
//# sourceMappingURL=store.d.ts.map