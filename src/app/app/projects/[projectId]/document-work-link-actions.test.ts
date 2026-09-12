import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  linkDocumentWorkCommand: vi.fn(),
  revalidatePath: vi.fn(),
  requireUser: vi.fn(async () => ({ id: "user-id" })),
  unlinkDocumentWorkCommand: vi.fn(),
}));

vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/server/auth/require-user", () => ({
  requireUser: mocks.requireUser,
}));
vi.mock("@/modules/document-work-links/server/commands", () => {
  class DocumentWorkLinkCommandError extends Error {
    constructor(readonly code: string) {
      super(code);
    }
  }

  return {
    DocumentWorkLinkCommandError,
    linkDocumentWorkCommand: mocks.linkDocumentWorkCommand,
    unlinkDocumentWorkCommand: mocks.unlinkDocumentWorkCommand,
  };
});

import { DocumentWorkLinkCommandError } from "@/modules/document-work-links/server/commands";

import {
  linkDocumentWork,
  unlinkDocumentWork,
} from "./document-work-link-actions";

const projectId = "10120000-0000-0000-0000-000000000001";
const documentId = "50120000-0000-0000-0000-000000000001";
const workId = "70120000-0000-0000-0000-000000000002";

describe("document work link actions", () => {
  beforeEach(() => vi.clearAllMocks());

  it("requires explicit active-Issue confirmation before calling the command", async () => {
    mocks.linkDocumentWorkCommand.mockRejectedValue(
      new DocumentWorkLinkCommandError("CONFIRMATION_REQUIRED"),
    );
    const formData = new FormData();
    formData.set("documentId", documentId);
    formData.set("workId", workId);

    const result = await linkDocumentWork(projectId, {}, formData);

    expect(result).toEqual({
      message:
        "Подтвердите создание влияния: у документа есть действующая выдача в производство.",
    });
    expect(mocks.linkDocumentWorkCommand).toHaveBeenCalledWith({
      confirmedActiveIssue: false,
      documentId,
      projectId,
      userId: "user-id",
      workId,
    });
  });

  it("returns a safe duplicate message without leaking database details", async () => {
    mocks.linkDocumentWorkCommand.mockRejectedValue(
      new DocumentWorkLinkCommandError("DUPLICATE"),
    );
    const formData = new FormData();
    formData.set("confirmedActiveIssue", "on");
    formData.set("documentId", documentId);
    formData.set("workId", workId);

    const result = await linkDocumentWork(projectId, {}, formData);

    expect(result).toEqual({ message: "Эта работа уже связана с документом." });
  });

  it("requires explicit historical-unlink confirmation", async () => {
    const formData = new FormData();
    formData.set("linkId", "80120000-0000-0000-0000-000000000001");

    const result = await unlinkDocumentWork(projectId, {}, formData);

    expect(result).toEqual({ message: "Связь не найдена или недоступна." });
    expect(mocks.unlinkDocumentWorkCommand).not.toHaveBeenCalled();
  });
});
