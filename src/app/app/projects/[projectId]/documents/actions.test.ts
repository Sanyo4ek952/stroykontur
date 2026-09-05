import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createDocumentRevisionCommand: vi.fn(),
  createTechnicalDocumentCommand: vi.fn(),
  redirect: vi.fn(),
  requireUser: vi.fn(async () => ({ id: "user-id" })),
}));

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/server/auth/require-user", () => ({
  requireUser: mocks.requireUser,
}));
vi.mock("@/modules/documents/server/commands", () => {
  class DocumentCommandError extends Error {
    constructor(readonly code: string) {
      super(code);
    }
  }

  return {
    createDocumentRevisionCommand: mocks.createDocumentRevisionCommand,
    createTechnicalDocumentCommand: mocks.createTechnicalDocumentCommand,
    DocumentCommandError,
  };
});

import { DocumentCommandError } from "@/modules/documents/server/commands";

import {
  createDocumentRevision,
  createTechnicalDocument,
  type DocumentActionState,
} from "./actions";

const projectId = "10120000-0000-0000-0000-000000000001";
const documentId = "20120000-0000-0000-0000-000000000001";
const initialState: DocumentActionState = {};

describe("document actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns a safe duplicate document message without leaking DB details", async () => {
    mocks.createTechnicalDocumentCommand.mockRejectedValue(
      new DocumentCommandError("DOCUMENT_DUPLICATE"),
    );
    const formData = new FormData();
    formData.set("code", "КЖ-01");
    formData.set("title", "Дубликат");

    const result = await createTechnicalDocument(
      projectId,
      initialState,
      formData,
    );

    expect(result).toEqual({
      message: "Документ с таким кодом уже существует.",
    });
    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it("returns a safe duplicate revision message", async () => {
    mocks.createDocumentRevisionCommand.mockRejectedValue(
      new DocumentCommandError("REVISION_DUPLICATE"),
    );
    const formData = new FormData();
    formData.set("revisionCode", "R2");

    const result = await createDocumentRevision(
      projectId,
      documentId,
      initialState,
      formData,
    );

    expect(result).toEqual({
      message: "Ревизия с таким кодом уже существует.",
    });
    expect(mocks.redirect).not.toHaveBeenCalled();
  });
});
