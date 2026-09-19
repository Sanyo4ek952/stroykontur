import Link from "next/link";
import {
  getDailyReports,
  getDailyReportAreas,
} from "@/modules/daily-reports/server/queries";
import { dailyReportStatuses } from "@/modules/daily-reports/model/schemas";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { EmptyState, PageIntro, formatDate } from "../ui";

export const metadata = { title: "Дневные отчёты" };
export default async function DailyReportsPage({
  params,
  searchParams,
}: {
  params: Promise<{ projectId: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { projectId } = await params;
  if (!postgresUuidSchema.safeParse(projectId).success)
    return <EmptyState title="Проект не найден." />;
  const [data, capabilities] = await Promise.all([
    getDailyReports(projectId, await searchParams),
    getDailyReportAreas(projectId),
  ]);
  const base = `/app/projects/${projectId}/daily-reports`;
  return (
    <>
      <PageIntro
        eyebrow="Производство"
        title="Дневные отчёты"
        description="Выполненные работы по зонам и датам. Объёмы становятся подтверждёнными после решения по всему отчёту."
      />
      {capabilities.some((a) => a.can_report) && (
        <Link
          className="inline-flex min-h-11 items-center rounded-xl bg-emerald-800 px-4 font-semibold text-white"
          href={base + "/new"}
        >
          Создать отчёт
        </Link>
      )}
      <form className="my-5 flex flex-wrap items-end gap-3">
        <label>
          Дата
          <input
            className="mt-1 block min-h-11 rounded-lg border p-2"
            type="date"
            name="date"
            defaultValue={data.filters.date ?? ""}
          />
        </label>
        <label>
          Статус
          <select
            className="mt-1 block min-h-11 rounded-lg border p-2"
            name="status"
            defaultValue={data.filters.status ?? ""}
          >
            <option value="">Все статусы</option>
            {dailyReportStatuses.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
        <label>
          Зона
          <select
            className="mt-1 block min-h-11 rounded-lg border p-2"
            name="area"
            defaultValue={data.filters.area ?? ""}
          >
            <option value="">Все зоны</option>
            {data.areas.map((a) => (
              <option key={a.id} value={a.id}>
                {a.code} · {a.name}
              </option>
            ))}
          </select>
        </label>
        <button className="min-h-11 rounded-lg border px-4" type="submit">
          Применить
        </button>
      </form>
      {data.reports.length === 0 ? (
        <EmptyState title="Дневных отчётов пока нет." />
      ) : (
        <ul className="space-y-3">
          {data.reports.map((r) => (
            <li key={r.id} className="rounded-xl border bg-white p-4">
              <Link
                className="font-semibold text-emerald-800 underline"
                href={base + "/" + r.id}
              >
                Отчёт за {formatDate(r.report_date)} · {r.area?.code} ·{" "}
                {r.area?.name}
              </Link>
              <p className="mt-2">
                {r.status} · Работников: {r.workers_count} · Записей прогресса:{" "}
                {r.progressCount}
              </p>
              <p className="text-sm text-slate-600">
                Автор: участник {r.prepared_by_project_member_id.slice(0, 8)}
              </p>
              {r.return_reason && (
                <p className="mt-2 text-red-800">
                  Причина возврата: {r.return_reason}
                </p>
              )}
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
