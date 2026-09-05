"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { postgresUuidSchema, workSchema } from "@/modules/works/model/schemas";
import {
  createWorkCommand,
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
  UNEXPECTED: "Не удалось сохранить работу. Обновите страницу и повторите.",
  WORK_DUPLICATE: "Работа с таким кодом уже существует.",
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
