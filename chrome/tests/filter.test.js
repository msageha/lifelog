import { describe, it, expect } from "@jest/globals";
import {
  evaluateRules,
  isTrackableUrl,
  migrateBlocklistToRules,
  DEFAULT_RULES,
} from "../lib/filter.js";

const DEFAULT_SETTINGS = { minDwellSeconds: 5, minContentChars: 100 };

describe("isTrackableUrl", () => {
  it("allows http URLs", () => {
    expect(isTrackableUrl("http://example.com")).toBe(true);
  });

  it("allows https URLs", () => {
    expect(isTrackableUrl("https://example.com")).toBe(true);
  });

  it("blocks chrome:// protocol", () => {
    expect(isTrackableUrl("chrome://extensions")).toBe(false);
  });

  it("blocks file:// protocol", () => {
    expect(isTrackableUrl("file:///home/user/file.html")).toBe(false);
  });

  it("returns false for empty string", () => {
    expect(isTrackableUrl("")).toBe(false);
  });

  it("returns false for invalid URL", () => {
    expect(isTrackableUrl("not-a-url")).toBe(false);
  });

  it("returns false for URL with special characters that fail parsing", () => {
    expect(isTrackableUrl("http://")).toBe(false);
  });
});

describe("evaluateRules - confidential/blocked sites (DEFAULT_RULES)", () => {
  it("blocks email site: mail.google.com", () => {
    const result = evaluateRules(
      "https://mail.google.com/mail/u/0/",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks email site: outlook.live.com", () => {
    const result = evaluateRules(
      "https://outlook.live.com/mail/0/",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks auth site: accounts.google.com", () => {
    const result = evaluateRules(
      "https://accounts.google.com/signin",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks auth site: login.microsoftonline.com", () => {
    const result = evaluateRules(
      "https://login.microsoftonline.com/common",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks auth site: *.okta.com wildcard", () => {
    const result = evaluateRules(
      "https://mycompany.okta.com/app",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks auth site: *.auth0.com wildcard", () => {
    const result = evaluateRules(
      "https://myapp.auth0.com/login",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks payment site: *.paypal.com wildcard", () => {
    const result = evaluateRules(
      "https://www.paypal.com/checkout",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks payment site: *.stripe.com wildcard", () => {
    const result = evaluateRules(
      "https://dashboard.stripe.com/payments",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks banking site: *.chase.com wildcard", () => {
    const result = evaluateRules(
      "https://www.chase.com/personal/banking",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks banking site: *.bankofamerica.com wildcard", () => {
    const result = evaluateRules(
      "https://www.bankofamerica.com/",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks password manager: *.1password.com wildcard", () => {
    const result = evaluateRules(
      "https://my.1password.com/vaults",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });
});

describe("evaluateRules - allowed sites", () => {
  it("allows general website: example.com", () => {
    const result = evaluateRules(
      "https://example.com/page",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(false);
  });

  it("allows general website: github.com", () => {
    const result = evaluateRules(
      "https://github.com/user/repo",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(false);
  });

  it("returns globalSettings minDwell for unmatched URL", () => {
    const result = evaluateRules(
      "https://example.com",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.minDwell).toBe(DEFAULT_SETTINGS.minDwellSeconds);
  });

  it("returns globalSettings minContent for unmatched URL", () => {
    const result = evaluateRules(
      "https://example.com",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.minContent).toBe(DEFAULT_SETTINGS.minContentChars);
  });

  it("allows x.com root (has allow rule after blocked subpaths)", () => {
    const result = evaluateRules(
      "https://x.com/someuser",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(false);
    expect(result.trackTweets).toBe(true);
  });
});

describe("evaluateRules - custom rules", () => {
  it("blocks URL matching custom domain rule", () => {
    const rules = [{ pattern: "example.com", action: "block" }];
    const result = evaluateRules(
      "https://example.com/page",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("blocks URL matching custom path rule", () => {
    const rules = [{ pattern: "example.com/private", action: "block" }];
    const result = evaluateRules(
      "https://example.com/private/docs",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("does not block sibling path when path rule is set", () => {
    const rules = [
      { pattern: "example.com/private", action: "block" },
      { pattern: "example.com", action: "allow" },
    ];
    const result = evaluateRules(
      "https://example.com/public",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(false);
  });

  it("first matching rule wins (block before allow)", () => {
    const rules = [
      { pattern: "example.com", action: "block" },
      { pattern: "example.com", action: "allow" },
    ];
    const result = evaluateRules(
      "https://example.com/page",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("first matching rule wins (allow before block)", () => {
    const rules = [
      { pattern: "example.com", action: "allow" },
      { pattern: "example.com", action: "block" },
    ];
    const result = evaluateRules(
      "https://example.com/page",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(false);
  });

  it("wildcard rule blocks subdomain", () => {
    const rules = [{ pattern: "*.example.com", action: "block" }];
    const result = evaluateRules(
      "https://sub.example.com/page",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("custom rule overrides globalSettings minDwell", () => {
    const rules = [
      { pattern: "example.com", action: "allow", minDwell: 30 },
    ];
    const result = evaluateRules(
      "https://example.com",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.minDwell).toBe(30);
  });

  it("custom rule overrides globalSettings minContent", () => {
    const rules = [
      { pattern: "example.com", action: "allow", minContent: 500 },
    ];
    const result = evaluateRules(
      "https://example.com",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.minContent).toBe(500);
  });
});

describe("evaluateRules - edge cases", () => {
  it("returns blocked for non-http URL (chrome://)", () => {
    const result = evaluateRules(
      "chrome://extensions",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
    expect(result.rule).toBeNull();
  });

  it("returns blocked for empty string URL", () => {
    const result = evaluateRules("", DEFAULT_RULES, DEFAULT_SETTINGS);
    expect(result.blocked).toBe(true);
  });

  it("returns blocked for invalid URL", () => {
    const result = evaluateRules(
      "not-a-url",
      DEFAULT_RULES,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("handles empty rules array (falls through to defaults)", () => {
    const result = evaluateRules("https://example.com", [], DEFAULT_SETTINGS);
    expect(result.blocked).toBe(false);
    expect(result.minDwell).toBe(DEFAULT_SETTINGS.minDwellSeconds);
  });

  it("is case-insensitive for domain matching", () => {
    const rules = [{ pattern: "EXAMPLE.COM", action: "block" }];
    const result = evaluateRules(
      "https://example.com/page",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });

  it("ignores trailing slash differences", () => {
    const rules = [{ pattern: "example.com/", action: "block" }];
    const result = evaluateRules(
      "https://example.com",
      rules,
      DEFAULT_SETTINGS
    );
    expect(result.blocked).toBe(true);
  });
});

describe("migrateBlocklistToRules", () => {
  it("converts string array to block rules", () => {
    const result = migrateBlocklistToRules(["example.com", "test.com"]);
    expect(result).toEqual([
      { pattern: "example.com", action: "block" },
      { pattern: "test.com", action: "block" },
    ]);
  });

  it("trims whitespace from patterns", () => {
    const result = migrateBlocklistToRules(["  example.com  "]);
    expect(result).toEqual([{ pattern: "example.com", action: "block" }]);
  });

  it("filters out empty strings after trim", () => {
    const result = migrateBlocklistToRules(["example.com", "  ", ""]);
    expect(result).toEqual([{ pattern: "example.com", action: "block" }]);
  });

  it("returns null for non-array input", () => {
    expect(migrateBlocklistToRules(null)).toBeNull();
    expect(migrateBlocklistToRules("string")).toBeNull();
    expect(migrateBlocklistToRules(42)).toBeNull();
  });

  it("returns empty array for empty input array", () => {
    expect(migrateBlocklistToRules([])).toEqual([]);
  });
});
