import type { Metadata } from "next";
import Link from "next/link";

import {
  getWorkProgressStatusLabel,
  getWorkProgressTotals,
} from "@/modules/works/model/progress";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { getWorkDocumentLinkData } from "@/modules/document-work-links/server/queries";
import {
  getWorkAssignmentCandidates,
  getWorkCapabilities,
  getWorkDetails,
  canConfirmWorkProgress,
  canReportWorkProgress,
} from "@/modules/works/server/queries";

import { DocumentWorkLinkManager } from "../../document-work-link-manager";
import { WorkAssignmentControls } from "./assignment-controls";
import { WorkLifecycleControls } from "./lifecycle-controls";
import {
  WorkProgressControls,
  WorkProgressDecisionControls,
} from "./progress-controls";
import { getWorkLifecycleActions } from "@/modules/works/model/lifecycle";
import {
  Detail,
  EmptyState,
  formatDate,
  formatDateTime,
  PageIntro,
  StatusBadge,
} from "../../ui";

export const metadata: Metadata = { title: "Карточка работы" };

function RelatedWorks({
  empty,
  items,
  projectId,
}: {
  empty: string;
  items: { code: string; id: string; status: string; title: string }[];
  projectId: string;
}) {
  return items.length === 0 ? (
    <p className="mt-3 text-sm text-slate-600">{empty}</p>
  ) : (
    <ul className="mt-3 space-y-2">
      {items.map((item) => (
        <li className="rounded-xl border border-slate-200 p-3" key={item.id}>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="text-xs font-bold text-emerald-700">{item.code}</p>
              <Link
                className="mt-1 block font-semibold text-slate-950 hover:text-emerald-800 hover:underline"
                href={`/app/projects/${projectId}/works/${item.id}`}
              >
                {item.title}
              </Link>
            </div>
            <StatusBadge status={item.status} />
          </div>
        </li>
      ))}
    </ul>
  );
}

export default async function WorkDetailsPage({
  params,
  searchParams,
}: {
  params: Promise<{ projectId: string; workId: string }>;
  searchParams: Promise<{ documentSearch?: string }>;
}) {
  const { projectId, workId } = await params;
  const { documentSearch = "" } = await searchParams;
  const parsedWorkId = postgresUuidSchema.safeParse(workId);
  if (!parsedWorkId.success) return <EmptyState title="Работа не найдена." />;

  const [work, linkData, capabilities] = await Promise.all([
    getWorkDetails(projectId, parsedWorkId.data),
    getWorkDocumentLinkData(
      projectId,
      parsedWorkId.data,
      documentSearch.trim(),
    ),
    getWorkCapabilities(projectId),
  ]);
  if (!work) return <EmptyState title="Работа не найдена." />;

  const [canReportProgress, canConfirmProgress] = await Promise.all([
    canReportWorkProgress(projectId, work.project_area_id),
    canConfirmWorkProgress(projectId, work.project_area_id),
  ]);
  const progressTotals = getWorkProgressTotals(work.progress);
  const candidates = capabilities.canAssignWork
    ? await getWorkAssignmentCandidates(projectId)
    : [];
  const availableActions = getWorkLifecycleActions(work.status, capabilities);

  return (
    <>
      <Link
        className="mb-4 inline-flex text-sm font-semibold text-emerald-800 hover:underline"
        href={`/app/projects/${projectId}/works`}
      >
        ← К работам
      </Link>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <PageIntro
          description="Плановые данные, ответственность, зависимости и фактическая история прогресса."
          eyebrow={work.code}
          title={work.title}
        />
        <StatusBadge status={work.status} />
      </div>

      <section className="rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-lg font-semibold text-slate-950">Работа</h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Detail label="Код">{work.code}</Detail>
          <Detail label="Зона">{work.areaLabel}</Detail>
          <Detail label="Плановый объём">
            {work.planned_quantity === null
              ? "Не задан"
              : `${work.planned_quantity} ${work.unit}`}
          </Detail>
          <Detail label="Плановый старт">
            {formatDate(work.planned_start_date)}
          </Detail>
          <Detail label="Плановый финиш">
            {formatDate(work.planned_finish_date)}
          </Detail>
        </dl>
      </section>

      <WorkLifecycleControls
        availableActions={availableActions}
        projectId={projectId}
        workId={work.id}
      />

      <DocumentWorkLinkManager
        canManage={linkData.canManage}
        candidates={linkData.candidates}
        fixedId={work.id}
        items={linkData.links.map((link) => ({
          code: link.document.code,
          id: link.id,
          removedAt: link.removed_at,
          removalReason: link.removal_reason,
          secondary: link.latestRevision
            ? `Ревизия ${link.latestRevision.revision_code} · ${link.latestRevision.status}${link.hasActiveIssue ? " · действует выдача в производство" : ""}`
            : link.hasActiveIssue
              ? "Действует выдача в производство"
              : "Ревизий нет",
          title: link.document.title,
          url: `/app/projects/${projectId}/documents/${link.document.id}`,
        }))}
        mode="work"
        projectId={projectId}
        search={documentSearch}
      />

      <section className="mt-6 rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-lg font-semibold text-slate-950">Ответственный</h2>
        {capabilities.canAssignWork ? (
          <WorkAssignmentControls
            projectId={projectId}
            workId={work.id}
            currentAssignment={work.currentAssignment}
            candidates={candidates}
          />
        ) : null}
        <p className="mt-4 text-base font-semibold text-slate-950">
          {work.currentAssignment?.responsibleLabel ?? "Не назначен"}
        </p>
        {work.assignmentHistory.length > 0 ? (
          <ol className="mt-4 space-y-2">
            {work.assignmentHistory.map((assignment) => (
              <li
                className="rounded-xl border border-slate-200 p-3"
                key={assignment.id}
              >
                <div className="flex flex-wrap justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-950">
                      {assignment.responsibleLabel}
                    </p>
                    <p className="mt-1 text-sm text-slate-600">
                      Назначен {formatDateTime(assignment.assigned_at)} ·{" "}
                      {assignment.assignedByLabel}
                    </p>
                  </div>
                  <span className="text-sm font-medium text-slate-600">
                    {assignment.ended_at
                      ? `Завершено ${formatDateTime(assignment.ended_at)}`
                      : "Текущее назначение"}
                  </span>
                </div>
                {assignment.assignment_reason ? (
                  <p className="mt-2 text-sm text-slate-600">
                    Основание: {assignment.assignment_reason}
                  </p>
                ) : null}
                {assignment.end_reason ? (
                  <p className="mt-2 text-sm text-slate-600">
                    Причина: {assignment.end_reason}
                  </p>
                ) : null}
              </li>
            ))}
          </ol>
        ) : null}
      </section>

      <section className="mt-6">
        <h2 className="text-xl font-semibold text-slate-950">Зависимости</h2>
        <p className="mt-1 text-sm text-slate-600">Только просмотр.</p>
        <div className="mt-3 grid gap-4 lg:grid-cols-2">
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <h3 className="font-semibold text-slate-950">Зависит от</h3>
            <RelatedWorks
              empty="Активных зависимостей нет."
              items={work.blockedBy}
              projectId={projectId}
            />
          </div>
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <h3 className="font-semibold text-slate-950">Блокирует</h3>
            <RelatedWorks
              empty="Эта работа не блокирует другие работы."
              items={work.blocks}
              projectId={projectId}
            />
          </div>
        </div>
      </section>

      <section className="mt-6">
        <h2 className="text-xl font-semibold text-slate-950">
          История прогресса
        </h2>
        <p className="mt-1 text-sm text-slate-600">
          Подтверждённый итог не меняет статус работы и включает только
          подтверждённые записи.
        </p>
        {canReportProgress ? (
          <WorkProgressControls projectId={projectId} workId={work.id} />
        ) : null}
        <dl className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <Detail label="Подтверждено">
            {progressTotals.confirmed} {work.unit ?? "ед."}
          </Detail>
          <Detail label="Ожидает подтверждения">
            {progressTotals.reported} {work.unit ?? "ед."}
          </Detail>
          <Detail label="Плановый объём">
            {work.planned_quantity === null
              ? "Не задан"
              : `${work.planned_quantity} ${work.unit ?? "ед."}`}
          </Detail>
          <Detail label="Возвращено">
            {progressTotals.returned} {work.unit ?? "ед."}
          </Detail>
        </dl>
        <p className="mt-4 text-base font-semibold text-slate-950">
          Итого выполнено: {progressTotals.confirmed} {work.unit ?? "ед."}
        </p>
        {work.progress.length === 0 ? (
          <div className="mt-3">
            <EmptyState title="Прогресс по работе ещё не зафиксирован." />
          </div>
        ) : (
          <ol className="mt-3 space-y-3">
            {work.progress.map((entry) => (
              <li
                className="rounded-2xl border border-slate-200 bg-white p-4"
                key={entry.id}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-950">
                      {entry.quantity} {work.unit ?? "ед."}
                    </p>
                    <p className="mt-1 text-sm text-slate-600">
                      Дата работ: {formatDate(entry.work_date)}
                    </p>
                  </div>
                  <div className="text-right text-sm text-slate-600">
                    <p>
                      {getWorkProgressStatusLabel(
                        entry.confirmation_status,
                        entry.return_reason,
                      )}
                    </p>
                    <p className="mt-1">
                      {formatDateTime(entry.created_at)} · {entry.reporterLabel}
                    </p>
                  </div>
                </div>
                {entry.note ? (
                  <p className="mt-3 text-sm leading-6 text-slate-700">
                    {entry.note}
                  </p>
                ) : null}
                {entry.confirmation_status === "CONFIRMED" &&
                entry.confirmed_at ? (
                  <p className="mt-3 text-sm text-slate-600">
                    Подтвердил {formatDateTime(entry.confirmed_at)} ·{" "}
                    {entry.confirmerLabel}
                  </p>
                ) : null}
                {entry.confirmation_status === "RETURNED" &&
                entry.returned_at ? (
                  <p className="mt-3 text-sm text-slate-600">
                    Вернул {formatDateTime(entry.returned_at)} ·{" "}
                    {entry.returnerLabel}
                  </p>
                ) : null}
                {canConfirmProgress &&
                entry.confirmation_status === "REPORTED" ? (
                  <WorkProgressDecisionControls
                    projectId={projectId}
                    workId={work.id}
                    workProgressEntryId={entry.id}
                  />
                ) : null}
              </li>
            ))}
          </ol>
        )}
      </section>
    </>
  );
}
