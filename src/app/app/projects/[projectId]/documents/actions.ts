"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import {
  documentRevisionSchema,
  postgresUuidSchema,
  technicalDocumentSchema,
} from "@/modules/documents/model/schemas";
import {
  createDocumentRevisionCommand,
  createTechnicalDocumentCommand,
  DocumentCommandError,
  type DocumentCommandErrorCode,
  issueDocumentRevisionForWorkCommand,
} from "@/modules/documents/server/commands";
import { requireUser } from "@/server/auth/require-user";

export type DocumentActionState = {
  fieldErrors?: {
    code?: string[];
    revisionCode?: string[];
    title?: string[];
  };
  message?: string;
  success?: boolean;
};

const errorMessages: Record<DocumentCommandErrorCode, string> = {
  DOCUMENT_DUPLICATE: "Документ с таким кодом уже существует.",
  DOCUMENT_NOT_FOUND: "Документ не найден.",
  FORBIDDEN: "Недостаточно прав для выполнения операции.",
  PROJECT_NOT_FOUND: "Проект не найден или недоступен.",
  REVISION_DUPLICATE: "Ревизия с таким кодом уже существует.",
  REVISION_NOT_APPROVED:
    "Выдать в производство можно только утверждённую ревизию.",
  UNEXPECTED: "Не удалось сохранить данные. Обновите страницу и повторите.",
};

function actionError(error: unknown): DocumentActionState {
  return {
    message:
      error instanceof DocumentCommandError
        ? errorMessages[error.code]
        : errorMessages.UNEXPECTED,
  };
}

export async function createTechnicalDocument(
  projectId: string,
  _state: DocumentActionState,
  formData: FormData,
): Promise<DocumentActionState> {
  const parsedProjectId = postgresUuidSchema.safeParse(projectId);
  const parsed = technicalDocumentSchema.safeParse({
    code: formData.get("code"),
    title: formData.get("title"),
  });

  if (!parsedProjectId.success) return { message: "Проект не найден." };
  if (!parsed.success) {
    return { fieldErrors: parsed.error.flatten().fieldErrors };
  }

  const user = await requireUser();
  let documentId: string;
  try {
    const document = await createTechnicalDocumentCommand({
      ...parsed.data,
      projectId: parsedProjectId.data,
      userId: user.id,
    });
    documentId = document.id;
  } catch (error) {
    return actionError(error);
  }

  const documentsPath = `/app/projects/${parsedProjectId.data}/documents`;
  revalidatePath(documentsPath);
  revalidatePath(`/app/projects/${parsedProjectId.data}`);
  redirect(`${documentsPath}/${documentId}`);
}

export async function createDocumentRevision(
  projectId: string,
  documentId: string,
  _state: DocumentActionState,
  formData: FormData,
): Promise<DocumentActionState> {
  const parsedContext = z
    .object({
      documentId: postgresUuidSchema,
      projectId: postgresUuidSchema,
    })
    .safeParse({ documentId, projectId });
  const parsed = documentRevisionSchema.safeParse({
    revisionCode: formData.get("revisionCode"),
  });

  if (!parsedContext.success) return { message: "Документ не найден." };
  if (!parsed.success) {
    return { fieldErrors: parsed.error.flatten().fieldErrors };
  }

  const user = await requireUser();
  try {
    await createDocumentRevisionCommand({
      ...parsed.data,
      ...parsedContext.data,
      userId: user.id,
    });
  } catch (error) {
    return actionError(error);
  }

  const documentPath = `/app/projects/${parsedContext.data.projectId}/documents/${parsedContext.data.documentId}`;
  revalidatePath(documentPath);
  revalidatePath(`/app/projects/${parsedContext.data.projectId}/documents`);
  redirect(documentPath);
}

export async function issueDocumentRevisionForWork(
  projectId: string,
  documentId: string,
  revisionId: string,
  _state: DocumentActionState,
  _formData: FormData,
): Promise<DocumentActionState> {
  void _state;
  void _formData;
  const parsed = z
    .object({
      documentId: postgresUuidSchema,
      projectId: postgresUuidSchema,
      revisionId: postgresUuidSchema,
    })
    .safeParse({ documentId, projectId, revisionId });

  if (!parsed.success) return { message: "Документ или ревизия не найдены." };

  await requireUser();
  try {
    await issueDocumentRevisionForWorkCommand(parsed.data);
  } catch (error) {
    return actionError(error);
  }

  const documentPath = `/app/projects/${parsed.data.projectId}/documents/${parsed.data.documentId}`;
  revalidatePath(documentPath);
  revalidatePath(`/app/projects/${parsed.data.projectId}/documents`);
  revalidatePath(`/app/projects/${parsed.data.projectId}`);
  return { message: "Ревизия выдана в производство.", success: true };
}
