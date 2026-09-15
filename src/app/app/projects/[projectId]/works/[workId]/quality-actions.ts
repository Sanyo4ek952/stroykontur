"use server";

import { revalidatePath } from "next/cache";

import { inspectionResultSchema } from "@/modules/quality/model/schemas";
import {
  acceptWorkInspectionCommand,
  QualityInspectionCommandError,
  type QualityInspectionCommandErrorCode,
  requestWorkInspectionCommand,
  scheduleWorkInspectionCommand,
  startWorkInspectionCommand,
} from "@/modules/quality/server/commands";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { requireUser } from "@/server/auth/require-user";

export type QualityInspectionActionState = {
  fieldErrors?: { resultNote?: string[] };
  message?: string;
};

const messages: Record<QualityInspectionCommandErrorCode, string> = {
  CONFLICT: "Команда уже использована для другого действия. Обновите страницу.",
  FORBIDDEN: "Недостаточно прав для контроля качества этой работы.",
  INVALID_RESULT: "Укажите корректный результат проверки.",
  NOT_FOUND: "Вызов или проверка не найдены.",
  NOT_INSPECTOR: "Продолжить может только инженер, принявший этот вызов.",
  STATE_UNAVAILABLE:
    "Действие недоступно в текущем состоянии. Обновите страницу.",
  UNEXPECTED: "Не удалось выполнить действие. Обновите страницу и повторите.",
};

function actionError(error: unknown): QualityInspectionActionState {
  return {
    message:
      error instanceof QualityInspectionCommandError
        ? messages[error.code]
        : messages.UNEXPECTED,
  };
}

function parseContext(projectId: string, workId: string) {
  const project = postgresUuidSchema.safeParse(projectId);
  const work = postgresUuidSchema.safeParse(workId);
  return project.success && work.success
    ? { projectId: project.data, workId: work.data }
    : null;
}

function revalidateWork(projectId: string, workId: string) {
  revalidatePath(`/app/projects/${projectId}/works`);
  revalidatePath(`/app/projects/${projectId}/works/${workId}`);
}

export async function requestWorkInspection(
  projectId: string,
  workId: string,
  _state: QualityInspectionActionState,
): Promise<QualityInspectionActionState> {
  void _state;
  const context = parseContext(projectId, workId);
  if (!context) return { message: "Работа не найдена." };
  await requireUser();
  try {
    await requestWorkInspectionCommand({
      commandId: crypto.randomUUID(),
      workId: context.workId,
    });
  } catch (error) {
    return actionError(error);
  }
  revalidateWork(context.projectId, context.workId);
  return {};
}

export async function scheduleWorkInspection(
  projectId: string,
  workId: string,
  inspectionRequestId: string,
  _state: QualityInspectionActionState,
): Promise<QualityInspectionActionState> {
  void _state;
  const context = parseContext(projectId, workId);
  const request = postgresUuidSchema.safeParse(inspectionRequestId);
  if (!context || !request.success) return { message: "Вызов не найден." };
  await requireUser();
  try {
    await scheduleWorkInspectionCommand({
      commandId: crypto.randomUUID(),
      inspectionRequestId: request.data,
    });
  } catch (error) {
    return actionError(error);
  }
  revalidateWork(context.projectId, context.workId);
  return {};
}

export async function startWorkInspection(
  projectId: string,
  workId: string,
  inspectionId: string,
  _state: QualityInspectionActionState,
): Promise<QualityInspectionActionState> {
  void _state;
  const context = parseContext(projectId, workId);
  const inspection = postgresUuidSchema.safeParse(inspectionId);
  if (!context || !inspection.success)
    return { message: "Проверка не найдена." };
  await requireUser();
  try {
    await startWorkInspectionCommand({
      commandId: crypto.randomUUID(),
      inspectionId: inspection.data,
    });
  } catch (error) {
    return actionError(error);
  }
  revalidateWork(context.projectId, context.workId);
  return {};
}

export async function acceptWorkInspection(
  projectId: string,
  workId: string,
  inspectionId: string,
  _state: QualityInspectionActionState,
  formData: FormData,
): Promise<QualityInspectionActionState> {
  const context = parseContext(projectId, workId);
  const inspection = postgresUuidSchema.safeParse(inspectionId);
  const result = inspectionResultSchema.safeParse({
    resultNote: formData.get("resultNote"),
  });
  if (!context || !inspection.success)
    return { message: "Проверка не найдена." };
  if (!result.success) {
    return { fieldErrors: result.error.flatten().fieldErrors };
  }
  await requireUser();
  try {
    await acceptWorkInspectionCommand({
      commandId: crypto.randomUUID(),
      inspectionId: inspection.data,
      resultNote: result.data.resultNote,
    });
  } catch (error) {
    return actionError(error);
  }
  revalidateWork(context.projectId, context.workId);
  return {};
}
