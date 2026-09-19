import { test as base, expect } from "@playwright/test";
import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";

export type Credentials = { email: string; password: string };
type Scenario = {
  ids: {
    workCreatorProjectMember: string;
    project: string;
    work: string;
    blockedWork: string;
    technicalDocument: string;
    issueTechnicalDocument: string;
    lifecycleWork: string;
    reworkWork: string;
    areaA: string;
    areaB: string;
    dailyReportWork: string;
  };
  demoUser: Credentials;
  manager: Credentials;
  quality: Credentials;
  field: Credentials;
  siteManager: Credentials;
  areaBConfirmer: Credentials;
};

export const test = base.extend<{ scenario: Scenario }>({
  scenario: [
    async ({}, use, testInfo) => {
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
      if (
        !url ||
        !["127.0.0.1", "localhost"].includes(new URL(url).hostname) ||
        new URL(url).port !== "54321"
      ) {
        throw new Error(
          "E2E fixtures require the local Supabase on port 54321.",
        );
      }
      const { stdout } = await promisify(execFile)(process.execPath, [
        "scripts/seed-task-012-demo.mjs",
        "--e2e",
        randomUUID(),
      ]);
      const scenario: Scenario = JSON.parse(stdout.trim());
      await testInfo.attach("isolated-project", {
        body: scenario.ids.project,
        contentType: "text/plain",
      });
      // Keep immutable history for debugging; pnpm db:reset removes local fixtures.
      await use(scenario);
    },
    { timeout: 60_000 },
  ],
});
export { expect };
