"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/server/auth/require-user";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import {
  createDailyReportSchema,
  dailyReportDraftSchema,
  addDailyReportProgressSchema,
  returnDailyReportSchema,
} from "@/modules/daily-reports/model/schemas";
import {
  createDailyReportCommand,
  updateDailyReportDraftCommand,
  addDailyReportProgressCommand,
  submitDailyReportCommand,
  confirmDailyReportCommand,
  returnDailyReportCommand,
  DailyReportCommandError,
} from "@/modules/daily-reports/server/commands";

export type DailyReportActionState = {
  message?: string;
  nextCommandId?: string;
};
function errorState(error: unknown): DailyReportActionState {
  return {
    message:
      error instanceof DailyReportCommandError
        ? error.message
        : "Не удалось сохранить отчёт. Повторите попытку.",
  };
}
function invalidate(projectId: string) {
  revalidatePath(`/app/projects/${projectId}/daily-reports`, "layout");
  revalidatePath(`/app/projects/${projectId}/works`, "layout");
}
function validIds(projectId: string, reportId?: string) {
  return (
    postgresUuidSchema.safeParse(projectId).success &&
    (reportId === undefined || postgresUuidSchema.safeParse(reportId).success)
  );
}
export async function createDailyReport(
  projectId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const parsed = createDailyReportSchema.safeParse(Object.fromEntries(form));
  if (!validIds(projectId) || !parsed.success)
    return { message: "Проверьте зону, дату, численность и текст отчёта." };
  await requireUser();
  let id: string;
  try {
    const v = parsed.data;
    id = await createDailyReportCommand(projectId, {
      p_project_area_id: v.projectAreaId,
      p_report_date: v.reportDate,
      p_workers_count: v.workersCount,
      p_summary: v.summary,
      p_problems: v.problems,
      p_command_id: v.commandId,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  redirect(`/app/projects/${projectId}/daily-reports/${id}`);
}
export async function updateDailyReportDraft(
  projectId: string,
  reportId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const parsed = dailyReportDraftSchema.safeParse(Object.fromEntries(form));
  if (!validIds(projectId, reportId) || !parsed.success)
    return { message: "Проверьте численность и текст отчёта." };
  await requireUser();
  try {
    const v = parsed.data;
    await updateDailyReportDraftCommand(projectId, {
      p_daily_report_id: reportId,
      p_workers_count: v.workersCount,
      p_summary: v.summary,
      p_problems: v.problems,
      p_command_id: v.commandId,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  return { nextCommandId: crypto.randomUUID() };
}
export async function addDailyReportProgress(
  projectId: string,
  reportId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const parsed = addDailyReportProgressSchema.safeParse(
    Object.fromEntries(form),
  );
  if (!validIds(projectId, reportId) || !parsed.success)
    return {
      message:
        "Выберите работу и укажите положительный объём. Примечание — до 2000 символов.",
    };
  await requireUser();
  try {
    const v = parsed.data;
    await addDailyReportProgressCommand(projectId, {
      p_daily_report_id: reportId,
      p_work_id: v.workId,
      p_quantity: v.quantity,
      p_note: v.note ?? "",
      p_command_id: v.commandId,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  return { nextCommandId: crypto.randomUUID() };
}
export async function submitDailyReport(
  projectId: string,
  reportId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const command = postgresUuidSchema.safeParse(form.get("commandId"));
  if (!validIds(projectId, reportId) || !command.success)
    return { message: "Неверные данные команды." };
  await requireUser();
  try {
    await submitDailyReportCommand(projectId, {
      p_daily_report_id: reportId,
      p_command_id: command.data,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  return {};
}
export async function confirmDailyReport(
  projectId: string,
  reportId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const command = postgresUuidSchema.safeParse(form.get("commandId"));
  if (!validIds(projectId, reportId) || !command.success)
    return { message: "Неверные данные команды." };
  await requireUser();
  try {
    await confirmDailyReportCommand(projectId, {
      p_daily_report_id: reportId,
      p_command_id: command.data,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  return {};
}
export async function returnDailyReport(
  projectId: string,
  reportId: string,
  _state: DailyReportActionState,
  form: FormData,
): Promise<DailyReportActionState> {
  const parsed = returnDailyReportSchema.safeParse(Object.fromEntries(form));
  if (!validIds(projectId, reportId) || !parsed.success)
    return { message: "Укажите причину возврата (до 2000 символов)." };
  await requireUser();
  try {
    await returnDailyReportCommand(projectId, {
      p_daily_report_id: reportId,
      p_return_reason: parsed.data.reason,
      p_command_id: parsed.data.commandId,
    });
  } catch (error) {
    return errorState(error);
  }
  invalidate(projectId);
  return {};
}
