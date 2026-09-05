import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createWorkCommand: vi.fn(),
  redirect: vi.fn(),
  requireUser: vi.fn(async () => ({ id: "user-id" })),
}));

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/server/auth/require-user", () => ({
  requireUser: mocks.requireUser,
}));
vi.mock("@/modules/works/server/commands", () => {
  class WorkCommandError extends Error {
    constructor(readonly code: string) {
      super(code);
    }
  }

  return { createWorkCommand: mocks.createWorkCommand, WorkCommandError };
});

import { WorkCommandError } from "@/modules/works/server/commands";

import { createWork, type WorkActionState } from "./actions";

const projectId = "10120000-0000-0000-0000-000000000001";
const initialState: WorkActionState = {};

describe("work actions", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns a safe duplicate code message without leaking DB details", async () => {
    mocks.createWorkCommand.mockRejectedValue(
      new WorkCommandError("WORK_DUPLICATE"),
    );
    const formData = new FormData();
    formData.set("code", "WORK-FND-001");
    formData.set("title", "Дубликат");

    const result = await createWork(projectId, initialState, formData);

    expect(result).toEqual({
      message: "Работа с таким кодом уже существует.",
    });
    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it("rejects incoherent quantity and unit before the command", async () => {
    const formData = new FormData();
    formData.set("code", "WORK-02");
    formData.set("title", "Работа");
    formData.set("plannedQuantity", "5");

    const result = await createWork(projectId, initialState, formData);

    expect(result.fieldErrors?.unit).toContain(
      "Плановый объём и единицу измерения нужно указать вместе.",
    );
    expect(mocks.createWorkCommand).not.toHaveBeenCalled();
  });
});
