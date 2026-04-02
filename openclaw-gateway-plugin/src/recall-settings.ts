import { promises as fs } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const SETTINGS_PATH = join(
  homedir(),
  ".openclaw",
  "workspace",
  "memory",
  "recall-settings.json",
);

export interface ReactionSettings {
  webReactionsEnabled: boolean;
  voiceReactionsEnabled: boolean;
  lineDeliveryEnabled: boolean;
  vibetermDeliveryEnabled: boolean;
  webMinContentChars: number;
  updatedAt: string | null;
}

const DEFAULTS: Omit<ReactionSettings, "updatedAt"> = {
  webReactionsEnabled: true,
  voiceReactionsEnabled: true,
  lineDeliveryEnabled: true,
  vibetermDeliveryEnabled: true,
  webMinContentChars: 200,
};

export async function getReactionSettings(): Promise<ReactionSettings> {
  try {
    const raw = await fs.readFile(SETTINGS_PATH, "utf-8");
    const data = JSON.parse(raw) as Partial<ReactionSettings>;
    return {
      webReactionsEnabled: data.webReactionsEnabled ?? DEFAULTS.webReactionsEnabled,
      voiceReactionsEnabled: data.voiceReactionsEnabled ?? DEFAULTS.voiceReactionsEnabled,
      lineDeliveryEnabled: data.lineDeliveryEnabled ?? DEFAULTS.lineDeliveryEnabled,
      vibetermDeliveryEnabled: data.vibetermDeliveryEnabled ?? DEFAULTS.vibetermDeliveryEnabled,
      webMinContentChars: data.webMinContentChars ?? DEFAULTS.webMinContentChars,
      updatedAt: data.updatedAt ?? null,
    };
  } catch {
    return { ...DEFAULTS, updatedAt: null };
  }
}

export async function saveReactionSettings(
  settings: Partial<ReactionSettings>,
): Promise<ReactionSettings> {
  const current = await getReactionSettings();
  const merged: ReactionSettings = {
    webReactionsEnabled: settings.webReactionsEnabled ?? current.webReactionsEnabled,
    voiceReactionsEnabled: settings.voiceReactionsEnabled ?? current.voiceReactionsEnabled,
    lineDeliveryEnabled: settings.lineDeliveryEnabled ?? current.lineDeliveryEnabled,
    vibetermDeliveryEnabled: settings.vibetermDeliveryEnabled ?? current.vibetermDeliveryEnabled,
    webMinContentChars: settings.webMinContentChars ?? current.webMinContentChars,
    updatedAt: new Date().toISOString(),
  };
  const dir = join(homedir(), ".openclaw", "workspace", "memory");
  await fs.mkdir(dir, { recursive: true, mode: 0o700 });
  await fs.writeFile(SETTINGS_PATH, JSON.stringify(merged, null, 2), { encoding: "utf-8", mode: 0o600 });
  return merged;
}
