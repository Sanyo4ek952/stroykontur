import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({
  rpc: vi.fn(),
  maybeSingle: vi.fn(),
  eq: vi.fn(),
}));
vi.mock("server-only", () => ({}));
vi.mock("@/server/supabase/server", () => ({
  createServerSupabaseClient: async () => ({
    rpc: mocks.rpc,
    from: () => ({ select: () => ({ eq: mocks.eq }) }),
  }),
}));
import {
  confirmDailyReportCommand,
  returnDailyReportCommand,
  createDailyReportCommand,
} from "./commands";
const id = "aaaaaaaa-0000-0000-0000-000000000022";
describe("DailyReport command boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.eq.mockReturnValue({ eq: mocks.eq, maybeSingle: mocks.maybeSingle });
    mocks.maybeSingle.mockResolvedValue({ data: { id }, error: null });
    mocks.rpc.mockResolvedValue({ data: id, error: null });
  });
  it("passes the caller's durable command ID unchanged", async () => {
    await confirmDailyReportCommand(id, {
      p_daily_report_id: id,
      p_command_id: id,
    });
    expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("confirm_daily_report", {
      p_daily_report_id: id,
      p_command_id: id,
    });
  });
  it.each(["42501", "DR002", "DR003", "DR004", "XX000"])(
    "maps %s without exposing DB details",
    async (code) => {
      mocks.rpc.mockResolvedValue({
        error: { code, message: "secret internal SQL details" },
      });
      await expect(
        returnDailyReportCommand(id, {
          p_daily_report_id: id,
          p_command_id: id,
          p_return_reason: "incorrect",
        }),
      ).rejects.not.toThrow("secret internal SQL details");
    },
  );
  it("does not mutate a report outside the supplied project", async () => {
    mocks.maybeSingle.mockResolvedValue({ data: null, error: null });
    await expect(
      confirmDailyReportCommand(id, {
        p_daily_report_id: id,
        p_command_id: id,
      }),
    ).rejects.toThrow("не найдены");
    expect(mocks.eq).toHaveBeenCalledWith("project_id", id);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it("does not create using an Area outside the supplied project", async () => {
    mocks.maybeSingle.mockResolvedValue({ data: null, error: null });
    await expect(
      createDailyReportCommand(id, {
        p_project_area_id: id,
        p_report_date: "2026-09-13",
        p_workers_count: 1,
        p_summary: "",
        p_problems: "",
        p_command_id: id,
      }),
    ).rejects.toThrow("не найдены");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
