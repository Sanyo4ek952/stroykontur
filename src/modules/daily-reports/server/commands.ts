import "server-only";
import { createServerSupabaseClient } from "@/server/supabase/server";
import type { Database } from "@/server/supabase/database.types";

type Functions = Database["public"]["Functions"];
export class DailyReportCommandError extends Error {}
function fail(error: { code?: string }): never {
  const messages: Record<string, string> = {
    "42501": "Недостаточно прав для действия в этой зоне.",
    P0002: "Отчёт или зона не найдены.",
    DR002: "Команда уже использована с другими данными. Обновите страницу.",
    WP002: "Команда уже использована с другими данными. Обновите страницу.",
    DR003: "Состояние отчёта изменилось. Обновите страницу.",
    WP003: "Запись уже обработана. Обновите страницу.",
    DR004:
      "Отчёт должен содержать необработанные записи прогресса из одной зоны.",
    "23514": "Проверьте зону работы и данные отчёта.",
    "22023": "Проверьте введённые данные.",
  };
  throw new DailyReportCommandError(
    messages[error.code ?? ""] ??
      "Не удалось сохранить отчёт. Повторите попытку.",
  );
}
async function reportClient(projectId: string, reportId: string) {
  const client = await createServerSupabaseClient();
  const { data, error } = await client
    .from("daily_reports")
    .select("id")
    .eq("project_id", projectId)
    .eq("id", reportId)
    .maybeSingle();
  if (error) fail(error);
  if (!data) fail({ code: "P0002" });
  return client;
}
export async function createDailyReportCommand(
  projectId: string,
  args: Functions["create_daily_report"]["Args"],
) {
  const client = await createServerSupabaseClient();
  const area = await client
    .from("project_areas")
    .select("id")
    .eq("project_id", projectId)
    .eq("id", args.p_project_area_id)
    .maybeSingle();
  if (area.error) fail(area.error);
  if (!area.data) fail({ code: "P0002" });
  const { data, error } = await client.rpc("create_daily_report", args);
  if (error) fail(error);
  return data;
}
export async function updateDailyReportDraftCommand(
  projectId: string,
  args: Functions["update_daily_report_draft"]["Args"],
) {
  const client = await reportClient(projectId, args.p_daily_report_id);
  const { error } = await client.rpc("update_daily_report_draft", args);
  if (error) fail(error);
}
export async function addDailyReportProgressCommand(
  projectId: string,
  args: Functions["add_daily_report_progress"]["Args"],
) {
  const client = await reportClient(projectId, args.p_daily_report_id);
  const { error } = await client.rpc("add_daily_report_progress", args);
  if (error) fail(error);
}
export async function submitDailyReportCommand(
  projectId: string,
  args: Functions["submit_daily_report"]["Args"],
) {
  const client = await reportClient(projectId, args.p_daily_report_id);
  const { error } = await client.rpc("submit_daily_report", args);
  if (error) fail(error);
}
export async function confirmDailyReportCommand(
  projectId: string,
  args: Functions["confirm_daily_report"]["Args"],
) {
  const client = await reportClient(projectId, args.p_daily_report_id);
  const { error } = await client.rpc("confirm_daily_report", args);
  if (error) fail(error);
}
export async function returnDailyReportCommand(
  projectId: string,
  args: Functions["return_daily_report"]["Args"],
) {
  const client = await reportClient(projectId, args.p_daily_report_id);
  const { error } = await client.rpc("return_daily_report", args);
  if (error) fail(error);
}
