"use server";

import { revalidatePath } from "next/cache";
import { requireUser } from "@/server/auth/require-user";
import {
  assignWorkSchema,
  reassignWorkSchema,
} from "@/modules/works/model/assignment";
import {
  assignWorkCommand,
  reassignWorkCommand,
  AssignmentCommandError,
} from "@/modules/works/server/assignment-commands";

export type AssignmentActionState = { message?: string; success?: boolean };
function failure(error: unknown): AssignmentActionState {
  const messages: Record<string, string> = {
    WA001:
      "Ответственный уже изменён другим пользователем. Обновите страницу и повторите действие.",
    WA002:
      "Этот запрос уже использован с другими данными. Откройте форму заново.",
    WA003: "Выбранный участник недоступен для назначения. Обновите страницу.",
    "42501": "Недостаточно прав для назначения ответственного.",
    P0002: "Работа не найдена или недоступна.",
    "22023": "Проверьте участника и причину назначения (до 2000 символов).",
  };
  return {
    message:
      error instanceof AssignmentCommandError
        ? (messages[error.code] ??
          "Не удалось изменить ответственного. Повторите запрос.")
        : "Не удалось изменить ответственного. Повторите запрос.",
  };
}
function refresh(projectId: string, workId: string) {
  revalidatePath(`/app/projects/${projectId}/works`);
  revalidatePath(`/app/projects/${projectId}/works/${workId}`);
}
export async function assignWork(
  _state: AssignmentActionState,
  formData: FormData,
): Promise<AssignmentActionState> {
  const parsed = assignWorkSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success)
    return { message: "Выберите участника и проверьте данные формы." };
  await requireUser();
  try {
    await assignWorkCommand(parsed.data);
  } catch (error) {
    return failure(error);
  }
  refresh(parsed.data.projectId, parsed.data.workId);
  return { success: true, message: "Ответственный назначен." };
}
export async function reassignWork(
  _state: AssignmentActionState,
  formData: FormData,
): Promise<AssignmentActionState> {
  const parsed = reassignWorkSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success)
    return {
      message:
        "Выберите участника и укажите причину переназначения (до 2000 символов).",
    };
  await requireUser();
  try {
    await reassignWorkCommand(parsed.data);
  } catch (error) {
    return failure(error);
  }
  refresh(parsed.data.projectId, parsed.data.workId);
  return { success: true, message: "Ответственный переназначен." };
}
