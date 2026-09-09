"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { postgresUuidSchema, workSchema } from "@/modules/works/model/schemas";
import {
  acceptWorkCommand,
  blockWorkCommand,
  closeWorkCommand,
  createWorkCommand,
  markWorkReadyCommand,
  markWorkReadyForInspectionCommand,
  requireWorkReworkCommand,
  resumeBlockedWorkCommand,
  startWorkCommand,
  WorkCommandError,
  type WorkCommandErrorCode,
} from "@/modules/works/server/commands";
import { requireUser } from "@/server/auth/require-user";

export type WorkActionState = {
  fieldErrors?: {
    code?: string[];
    plannedFinishDate?: string[];
    plannedQuantity?: string[];
    plannedStartDate?: string[];
    title?: string[];
    unit?: string[];
  };
  message?: string;
};

const errorMessages: Record<WorkCommandErrorCode, string> = {
  FORBIDDEN: "Недостаточно прав для выполнения действия.",
  INVALID_DATES: "Дата окончания не может быть раньше даты начала.",
  INVALID_QUANTITY_UNIT: "Проверьте плановый объём и единицу измерения.",
  PROJECT_NOT_FOUND: "Проект не найден или недоступен.",
  TRANSITION_UNAVAILABLE: "Переход из текущего состояния недоступен.",
  UNEXPECTED: "Не удалось сохранить работу. Обновите страницу и повторите.",
  WORK_DUPLICATE: "Работа с таким кодом уже существует.",
  WORK_NOT_FOUND: "Работа не найдена.",
};

function actionError(error: unknown): WorkActionState {
  return {
    message:
      error instanceof WorkCommandError
        ? errorMessages[error.code]
        : errorMessages.UNEXPECTED,
  };
}

export async function createWork(
  projectId: string,
  _state: WorkActionState,
  formData: FormData,
): Promise<WorkActionState> {
  const parsedProjectId = postgresUuidSchema.safeParse(projectId);
  const parsed = workSchema.safeParse({
    code: formData.get("code"),
    plannedFinishDate: formData.get("plannedFinishDate"),
    plannedQuantity: formData.get("plannedQuantity"),
    plannedStartDate: formData.get("plannedStartDate"),
    title: formData.get("title"),
    unit: formData.get("unit"),
  });

  if (!parsedProjectId.success) return { message: "Проект не найден." };
  if (!parsed.success) {
    return { fieldErrors: parsed.error.flatten().fieldErrors };
  }

  const user = await requireUser();
  let workId: string;
  try {
    const work = await createWorkCommand({
      ...parsed.data,
      projectId: parsedProjectId.data,
      userId: user.id,
    });
    workId = work.id;
  } catch (error) {
    return actionError(error);
  }

  const worksPath = `/app/projects/${parsedProjectId.data}/works`;
  revalidatePath(worksPath);
  revalidatePath(`/app/projects/${parsedProjectId.data}`);
  redirect(`${worksPath}/${workId}`);
}

export type WorkLifecycleActionState = { message?: string };

async function runLifecycleAction(
  projectId: string,
  workId: string,
  command: (projectId: string, workId: string) => Promise<void>,
): Promise<WorkLifecycleActionState> {
  const parsedProjectId = postgresUuidSchema.safeParse(projectId);
  const parsedWorkId = postgresUuidSchema.safeParse(workId);
  if (!parsedProjectId.success || !parsedWorkId.success) {
    return { message: "Работа не найдена." };
  }
  await requireUser();
  try {
    await command(parsedProjectId.data, parsedWorkId.data);
  } catch (error) {
    return actionError(error);
  }
  const worksPath = `/app/projects/${parsedProjectId.data}/works`;
  revalidatePath(worksPath);
  revalidatePath(`${worksPath}/${parsedWorkId.data}`);
  return {};
}

export async function markWorkReady(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, markWorkReadyCommand);
}

export async function startWork(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, startWorkCommand);
}

export async function blockWork(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, blockWorkCommand);
}

export async function resumeBlockedWork(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, resumeBlockedWorkCommand);
}

export async function markWorkReadyForInspection(
  projectId: string,
  workId: string,
) {
  return runLifecycleAction(
    projectId,
    workId,
    markWorkReadyForInspectionCommand,
  );
}

export async function requireWorkRework(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, requireWorkReworkCommand);
}

export async function acceptWork(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, acceptWorkCommand);
}

export async function closeWork(projectId: string, workId: string) {
  return runLifecycleAction(projectId, workId, closeWorkCommand);
}
