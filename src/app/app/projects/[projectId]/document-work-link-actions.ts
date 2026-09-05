"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import { postgresUuidSchema } from "@/modules/documents/model/schemas";
import {
  DocumentWorkLinkCommandError,
  type DocumentWorkLinkCommandErrorCode,
  linkDocumentWorkCommand,
  unlinkDocumentWorkCommand,
} from "@/modules/document-work-links/server/commands";
import { requireUser } from "@/server/auth/require-user";

export type DocumentWorkLinkActionState = {
  message?: string;
  success?: boolean;
};

const linkSchema = z.object({
  confirmedActiveIssue: z.boolean(),
  documentId: postgresUuidSchema,
  projectId: postgresUuidSchema,
  workId: postgresUuidSchema,
});

const unlinkSchema = z.object({
  confirmedUnlink: z.literal(true),
  linkId: postgresUuidSchema,
  projectId: postgresUuidSchema,
  reason: z.string().trim().max(500).nullable(),
});

const errorMessages: Record<DocumentWorkLinkCommandErrorCode, string> = {
  ALREADY_REMOVED: "Связь уже была удалена.",
  CONFIRMATION_REQUIRED:
    "Подтвердите создание влияния: у документа есть действующая выдача в производство.",
  DUPLICATE: "Эта работа уже связана с документом.",
  ENDPOINT_NOT_FOUND: "Документ или работа недоступны.",
  FORBIDDEN: "Недостаточно прав для управления связями документа и работ.",
  LINK_NOT_FOUND: "Связь не найдена или недоступна.",
  UNEXPECTED: "Не удалось изменить связь. Обновите страницу и повторите.",
};

function actionError(error: unknown): DocumentWorkLinkActionState {
  return {
    message:
      error instanceof DocumentWorkLinkCommandError
        ? errorMessages[error.code]
        : errorMessages.UNEXPECTED,
  };
}

function revalidateLinkRoutes(
  projectId: string,
  documentId: string,
  workId: string,
) {
  revalidatePath(`/app/projects/${projectId}/documents/${documentId}`);
  revalidatePath(`/app/projects/${projectId}/works/${workId}`);
  revalidatePath(`/app/projects/${projectId}`);
}

export async function linkDocumentWork(
  projectId: string,
  _state: DocumentWorkLinkActionState,
  formData: FormData,
): Promise<DocumentWorkLinkActionState> {
  const parsed = linkSchema.safeParse({
    confirmedActiveIssue: formData.get("confirmedActiveIssue") === "on",
    documentId: formData.get("documentId"),
    projectId,
    workId: formData.get("workId"),
  });
  if (!parsed.success) return { message: "Документ или работа недоступны." };

  const user = await requireUser();
  try {
    const link = await linkDocumentWorkCommand({
      ...parsed.data,
      userId: user.id,
    });
    revalidateLinkRoutes(parsed.data.projectId, link.documentId, link.workId);
    return { message: "Связь создана.", success: true };
  } catch (error) {
    return actionError(error);
  }
}

export async function unlinkDocumentWork(
  projectId: string,
  _state: DocumentWorkLinkActionState,
  formData: FormData,
): Promise<DocumentWorkLinkActionState> {
  const rawReason = formData.get("reason");
  const parsed = unlinkSchema.safeParse({
    confirmedUnlink: formData.get("confirmedUnlink") === "on",
    linkId: formData.get("linkId"),
    projectId,
    reason:
      typeof rawReason === "string" && rawReason.trim() ? rawReason : null,
  });
  if (!parsed.success) return { message: "Связь не найдена или недоступна." };

  const user = await requireUser();
  try {
    const link = await unlinkDocumentWorkCommand({
      linkId: parsed.data.linkId,
      projectId: parsed.data.projectId,
      reason: parsed.data.reason,
      userId: user.id,
    });
    revalidateLinkRoutes(parsed.data.projectId, link.documentId, link.workId);
    return {
      message: "Связь закрыта. Исторические последствия сохранены.",
      success: true,
    };
  } catch (error) {
    return actionError(error);
  }
}
