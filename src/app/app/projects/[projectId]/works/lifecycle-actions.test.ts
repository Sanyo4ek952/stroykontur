import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({
  command: vi.fn(),
  requireUser: vi.fn(async () => ({ id: "actor" })),
  revalidatePath: vi.fn(),
}));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("@/server/auth/require-user", () => ({
  requireUser: mocks.requireUser,
}));
vi.mock("@/modules/works/server/commands", () => ({
  markWorkReadyCommand: mocks.command,
  startWorkCommand: mocks.command,
  blockWorkCommand: mocks.command,
  resumeBlockedWorkCommand: mocks.command,
  markWorkReadyForInspectionCommand: mocks.command,
  requireWorkReworkCommand: mocks.command,
  acceptWorkCommand: mocks.command,
  closeWorkCommand: mocks.command,
  createWorkCommand: vi.fn(),
  WorkCommandError: class extends Error {
    constructor(readonly code: string) {
      super(code);
    }
  },
}));
import { WorkCommandError } from "@/modules/works/server/commands";
import * as actions from "./actions";
const projectId = "10180000-0000-0000-0000-000000000001";
const workId = "70180000-0000-0000-0000-000000000001";
describe("Work lifecycle Server Actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.command.mockResolvedValue(undefined);
  });
  it.each([
    actions.markWorkReady,
    actions.startWork,
    actions.blockWork,
    actions.resumeBlockedWork,
    actions.markWorkReadyForInspection,
    actions.requireWorkRework,
    actions.acceptWork,
    actions.closeWork,
  ])("validates IDs and authenticates before command", async (action) => {
    expect(await action("bad", workId)).toEqual({
      message: "Работа не найдена.",
    });
    expect(mocks.command).not.toHaveBeenCalled();
    await action(projectId, workId);
    expect(mocks.requireUser).toHaveBeenCalledOnce();
    expect(mocks.command).toHaveBeenCalledExactlyOnceWith(projectId, workId);
    expect(mocks.revalidatePath).toHaveBeenCalledWith(
      `/app/projects/${projectId}/works/${workId}`,
    );
  });
  it.each([
    ["FORBIDDEN", "Недостаточно прав для выполнения действия."],
    ["TRANSITION_UNAVAILABLE", "Переход из текущего состояния недоступен."],
    ["WORK_NOT_FOUND", "Работа не найдена."],
  ] as const)("returns safe Russian %s errors", async (code, message) => {
    mocks.command.mockRejectedValue(new WorkCommandError(code));
    expect(await actions.startWork(projectId, workId)).toEqual({ message });
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });
  it("hides unexpected errors", async () => {
    mocks.command.mockRejectedValue(new Error("SQL secrets"));
    expect(await actions.closeWork(projectId, workId)).toEqual({
      message: "Не удалось сохранить работу. Обновите страницу и повторите.",
    });
  });
});
