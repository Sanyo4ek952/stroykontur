import { describe, expect, it } from "vitest";
import {
  createDailyReportSchema,
  addDailyReportProgressSchema,
  returnDailyReportSchema,
} from "./schemas";
const id = "aaaaaaaa-0000-0000-0000-000000000022";
const valid = {
  projectAreaId: id,
  reportDate: "2026-09-13",
  workersCount: "7",
  summary: " work ",
  problems: "",
  commandId: id,
};
describe("DailyReport inputs", () => {
  it("normalizes draft fields and accepts zero workers", () => {
    expect(
      createDailyReportSchema.parse({ ...valid, workersCount: "0" }),
    ).toMatchObject({ workersCount: 0, summary: "work" });
  });
  it.each([
    { reportDate: "2026-02-30" },
    { projectAreaId: "invalid" },
    { commandId: "" },
    { workersCount: "-1" },
    { workersCount: "1.5" },
    { workersCount: "100001" },
    { summary: "x".repeat(4001) },
  ])("rejects invalid report input %s", (patch) => {
    expect(
      createDailyReportSchema.safeParse({ ...valid, ...patch }).success,
    ).toBe(false);
  });
  it.each(["0", "-1", "Infinity", "NaN"])(
    "rejects invalid progress quantity %s",
    (quantity) => {
      expect(
        addDailyReportProgressSchema.safeParse({
          workId: id,
          commandId: id,
          quantity,
        }).success,
      ).toBe(false);
    },
  );
  it("reuses progress quantity rules and requires a command ID", () => {
    expect(
      addDailyReportProgressSchema.parse({
        workId: id,
        commandId: id,
        quantity: "2.5",
      }).quantity,
    ).toBe(2.5);
    expect(
      addDailyReportProgressSchema.safeParse({ workId: id, quantity: "2.5" })
        .success,
    ).toBe(false);
  });
  it("requires a trimmed bounded return reason", () => {
    expect(
      returnDailyReportSchema.safeParse({ commandId: id, reason: "  " })
        .success,
    ).toBe(false);
    expect(
      returnDailyReportSchema.safeParse({
        commandId: id,
        reason: "x".repeat(2001),
      }).success,
    ).toBe(false);
    expect(
      returnDailyReportSchema.parse({ commandId: id, reason: "  incorrect  " })
        .reason,
    ).toBe("incorrect");
  });
});
