import "server-only";
import { createServerSupabaseClient } from "@/server/supabase/server";
import { dailyReportStatuses } from "../model/schemas";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { z } from "zod";

export async function getDailyReportAreas(projectId: string) {
  const client = await createServerSupabaseClient();
  const { data, error } = await client
    .from("daily_report_area_capabilities")
    .select("*")
    .eq("project_id", projectId)
    .order("code");
  if (error) throw new Error("Не удалось проверить права на дневные отчёты.");
  return data.filter(
    (a): a is typeof a & { id: string; code: string; name: string } =>
      a.id !== null && a.code !== null && a.name !== null,
  );
}
export async function getDailyReports(
  projectId: string,
  input: Record<string, string | string[] | undefined>,
) {
  const first = (v: string | string[] | undefined) =>
    Array.isArray(v) ? v[0] : v;
  const date = z.iso
    .date()
    .optional()
    .catch(undefined)
    .parse(first(input.date));
  const status = z
    .enum(dailyReportStatuses)
    .optional()
    .catch(undefined)
    .parse(first(input.status));
  const area = postgresUuidSchema
    .optional()
    .catch(undefined)
    .parse(first(input.area));
  const client = await createServerSupabaseClient();
  let query = client
    .from("daily_reports")
    .select("*, work_progress_entries(count)")
    .eq("project_id", projectId)
    .order("report_date", { ascending: false })
    .order("created_at", { ascending: false });
  if (date) query = query.eq("report_date", date);
  if (status) query = query.eq("status", status);
  if (area) query = query.eq("project_area_id", area);
  const [reports, areas] = await Promise.all([
    query,
    client
      .from("project_areas")
      .select("id, code, name")
      .eq("project_id", projectId)
      .order("code"),
  ]);
  if (reports.error || areas.error)
    throw new Error("Не удалось загрузить дневные отчёты.");
  const byId = new Map(areas.data.map((a) => [a.id, a]));
  return {
    filters: { date, status, area },
    areas: areas.data,
    reports: reports.data.map((r) => ({
      ...r,
      area: byId.get(r.project_area_id),
      progressCount: r.work_progress_entries[0]?.count ?? 0,
    })),
  };
}
export async function getDailyReportDetails(
  projectId: string,
  reportId: string,
) {
  const client = await createServerSupabaseClient();
  const { data: report, error } = await client
    .from("daily_reports")
    .select("*")
    .eq("project_id", projectId)
    .eq("id", reportId)
    .maybeSingle();
  if (error) throw new Error("Не удалось загрузить дневной отчёт.");
  if (!report) return null;
  const [area, progress, works] = await Promise.all([
    client
      .from("project_areas")
      .select("code, name")
      .eq("project_id", projectId)
      .eq("id", report.project_area_id)
      .single(),
    client
      .from("work_progress_entries")
      .select("id, work_id, quantity, note, confirmation_status, return_reason")
      .eq("project_id", projectId)
      .eq("daily_report_id", report.id)
      .order("created_at"),
    client
      .from("works")
      .select("id, code, title, unit, planned_quantity")
      .eq("project_id", projectId)
      .eq("project_area_id", report.project_area_id)
      .order("code"),
  ]);
  if (area.error || progress.error || works.error)
    throw new Error("Не удалось загрузить работы отчёта.");
  const byId = new Map(works.data.map((w) => [w.id, w]));
  return {
    ...report,
    area: area.data,
    works: works.data.filter((w) => w.planned_quantity !== null),
    progress: progress.data.map((e) => ({ ...e, work: byId.get(e.work_id) })),
  };
}
