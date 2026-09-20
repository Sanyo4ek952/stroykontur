import { describe, expect, it } from "vitest";

import {
  mergePublicEnvironment,
  parseSupabaseConfig,
  validateLocalSupabaseUrl,
} from "./local-demo-support.mjs";

const config = parseSupabaseConfig(`
project_id = "construction-pwa"

[api]
port = 54321
`);

describe("local demo safety", () => {
  it("accepts only the configured loopback API", () => {
    expect(validateLocalSupabaseUrl("http://127.0.0.1:54321", config)).toBe(
      "http://127.0.0.1:54321",
    );
    expect(() =>
      validateLocalSupabaseUrl("https://example.com:54321", config),
    ).toThrow(/loopback Supabase/);
    expect(() =>
      validateLocalSupabaseUrl("http://127.0.0.1:54322", config),
    ).toThrow(/порт 54321/);
  });

  it("replaces only managed public values", () => {
    const result = mergePublicEnvironment(
      "CUSTOM_VALUE=keep\nNEXT_PUBLIC_SUPABASE_URL=https://example.com\n",
      { publishableKey: "local-key", url: "http://127.0.0.1:54321" },
    );
    expect(result).toContain("CUSTOM_VALUE=keep");
    expect(result).toContain("NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321");
    expect(result).toContain("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=local-key");
    expect(result).not.toContain("example.com");
  });
});
