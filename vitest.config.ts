import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  test: {
    environment: "jsdom",
    env: {
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-unit-test-key",
      NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
    },
    setupFiles: "./vitest.setup.ts",
    include: ["src/**/*.test.{ts,tsx}", "scripts/**/*.test.mjs"],
  },
});
