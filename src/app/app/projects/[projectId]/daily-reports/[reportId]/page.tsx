import Link from "next/link";
import {
  getDailyReportDetails,
  getDailyReportAreas,
} from "@/modules/daily-reports/server/queries";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { getWorkProgressStatusLabel } from "@/modules/works/model/progress";
import {
  Detail,
  EmptyState,
  PageIntro,
  formatDate,
  formatDateTime,
} from "../../ui";
import {
  DailyReportForm,
  DailyReportProgressForm,
  DailyReportSubmit,
  DailyReportDecision,
} from "../report-controls";

export const metadata = { title: "Дневной отчёт" };
const actor = (id: string | null) =>
  id ? `Участник проекта · ${id.slice(0, 8)}` : "—";
export default async function DailyReportDetailsPage({
  params,
}: {
  params: Promise<{ projectId: string; reportId: string }>;
}) {
  const { projectId, reportId } = await params;
  if (
    !postgresUuidSchema.safeParse(projectId).success ||
    !postgresUuidSchema.safeParse(reportId).success
  )
    return <EmptyState title="Отчёт не найден или недоступен." />;
  const [report, areas] = await Promise.all([
    getDailyReportDetails(projectId, reportId),
    getDailyReportAreas(projectId),
  ]);
  if (!report) return <EmptyState title="Отчёт не найден или недоступен." />;
  const capability = areas.find((a) => a.id === report.project_area_id);
  const canEdit = report.status === "DRAFT" && capability?.can_report;
  return (
    <>
      <Link
        className="text-emerald-800 underline"
        href={`/app/projects/${projectId}/daily-reports`}
      >
        К дневным отчётам
      </Link>
      <PageIntro
        eyebrow={report.area.code + " · " + report.area.name}
        title={"Отчёт за " + formatDate(report.report_date)}
        description="Решение применяется ко всем записям прогресса в отчёте."
      />
      <p data-testid="report-status" className="mb-4 font-semibold">
        {report.status}
      </p>
      <dl className="grid gap-4 rounded-xl border bg-white p-5 sm:grid-cols-2">
        <Detail label="Автор">
          {actor(report.prepared_by_project_member_id)}
        </Detail>
        <Detail label="Создан">{formatDateTime(report.created_at)}</Detail>
        <Detail label="Работников">{report.workers_count}</Detail>
        <Detail label="Выполненные работы">{report.summary || "—"}</Detail>
        <Detail label="Проблемы">{report.problems || "—"}</Detail>
        <Detail label="Отправлен">
          {formatDateTime(report.submitted_at)} ·{" "}
          {actor(report.submitted_by_project_member_id)}
        </Detail>
        <Detail label="Подтверждён">
          {formatDateTime(report.confirmed_at)} ·{" "}
          {actor(report.confirmed_by_project_member_id)}
        </Detail>
        <Detail label="Возвращён">
          {formatDateTime(report.returned_at)} ·{" "}
          {actor(report.returned_by_project_member_id)}
        </Detail>
      </dl>
      {report.return_reason && (
        <p className="mt-4 rounded-xl border border-red-200 p-4 text-red-800">
          Причина возврата: {report.return_reason}
        </p>
      )}
      {report.status === "RETURNED" && (
        <p className="mt-3 text-sm">
          Для исправления создайте новый дневной отчёт.
        </p>
      )}
      {canEdit && (
        <DailyReportForm
          projectId={projectId}
          reportId={reportId}
          commandId={crypto.randomUUID()}
          initial={report}
        />
      )}
      <h2 className="mt-6 text-xl font-semibold">Объёмы по работам</h2>
      {report.progress.length === 0 ? (
        <p className="mt-3">Добавьте минимум одну запись прогресса.</p>
      ) : (
        <ul className="mt-3 space-y-3">
          {report.progress.map((e) => (
            <li
              data-testid="report-progress"
              className="rounded-xl border bg-white p-4"
              key={e.id}
            >
              <Link
                className="font-semibold text-emerald-800 underline"
                href={`/app/projects/${projectId}/works/${e.work_id}`}
              >
                {e.work?.code} · {e.work?.title}
              </Link>
              <p>
                {e.quantity} {e.work?.unit}
              </p>
              <p>
                {getWorkProgressStatusLabel(
                  e.confirmation_status,
                  e.return_reason,
                )}
              </p>
              {e.note && <p className="text-sm text-slate-600">{e.note}</p>}
            </li>
          ))}
        </ul>
      )}
      {canEdit && (
        <>
          <DailyReportProgressForm
            projectId={projectId}
            reportId={reportId}
            commandId={crypto.randomUUID()}
            works={report.works}
          />
          <DailyReportSubmit
            projectId={projectId}
            reportId={reportId}
            commandId={crypto.randomUUID()}
          />
        </>
      )}
      {report.status === "SUBMITTED" && capability?.can_confirm && (
        <DailyReportDecision
          projectId={projectId}
          reportId={reportId}
          confirmCommandId={crypto.randomUUID()}
          returnCommandId={crypto.randomUUID()}
        />
      )}
    </>
  );
}
