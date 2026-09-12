import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("server-only", () => ({}));
vi.mock("@/server/supabase/server", () => ({
  createServerSupabaseClient: async () => ({ rpc: mocks.rpc }),
}));
import * as commands from "./commands";

const projectId = "10180000-0000-0000-0000-000000000001";
const workId = "70180000-0000-0000-0000-000000000001";
const cases = [
  [commands.markWorkReadyCommand, "mark_work_ready"],
  [commands.startWorkCommand, "start_work"],
  [commands.blockWorkCommand, "block_work"],
  [commands.resumeBlockedWorkCommand, "resume_blocked_work"],
  [
    commands.markWorkReadyForInspectionCommand,
    "mark_work_ready_for_inspection",
  ],
  [commands.requireWorkReworkCommand, "require_work_rework"],
  [commands.acceptWorkCommand, "accept_work"],
  [commands.closeWorkCommand, "close_work"],
] as const;

describe("named Work lifecycle commands", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.rpc.mockResolvedValue({ error: null });
  });
  it.each(cases)(
    "calls only the predefined RPC %s %s",
    async (command, rpc) => {
      await command(projectId, workId);
      expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith(rpc, {
        p_project_id: projectId,
        p_work_id: workId,
      });
    },
  );
  it.each([
    ["42501", "FORBIDDEN"],
    ["P0002", "WORK_NOT_FOUND"],
    ["22023", "TRANSITION_UNAVAILABLE"],
    ["XX000", "UNEXPECTED"],
  ])("maps %s without exposing raw SQL", async (code, expected) => {
    mocks.rpc.mockResolvedValue({
      error: { code, message: "private database details" },
    });
    await expect(
      commands.startWorkCommand(projectId, workId),
    ).rejects.toMatchObject({
      code: expected,
      message: expected,
    });
  });
});
