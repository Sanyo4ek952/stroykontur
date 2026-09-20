import type { Metadata } from "next";
import Link from "next/link";

import {
  inspectionRequestStatusLabels,
  inspectionStatusLabels,
} from "@/modules/quality/model/presentation";
import {
  getQualityInspectionCapabilities,
  getWorkQualityInspections,
} from "@/modules/quality/server/queries";
import {
  getWorkProgressStatusLabel,
  getWorkProgressTotals,
} from "@/modules/works/model/progress";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { getWorkDocumentLinkData } from "@/modules/document-work-links/server/queries";
import {
  getReadinessFailureMessages,
  workBlockerCategoryLabels,
  workBlockerStatusLabels,
  type WorkBlockerCategory,
} from "@/modules/works/model/readiness";
import {
  getWorkAssignmentCandidates,
  getWorkBlockers,
  getWorkCapabilities,
  getWorkDetails,
  getWorkReadiness,
  canConfirmWorkProgress,
  canReportWorkProgress,
} from "@/modules/works/server/queries";

import { DocumentWorkLinkManager } from "../../document-work-link-manager";
import { WorkAssignmentControls } from "./assignment-controls";
import {
  OpenWorkBlockerControl,
  ResolveWorkBlockerControl,
} from "./blocker-controls";
import { WorkLifecycleControls } from "./lifecycle-controls";
import {
  AcceptInspectionControl,
  RequestInspectionControl,
  ScheduleInspectionControl,
  StartInspectionControl,
} from "./quality-controls";
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

  const [readiness, blockers, qualityHistory, qualityCapabilities] =
    await Promise.all([
      getWorkReadiness(work.id),
      getWorkBlockers(projectId, work.id),
      getWorkQualityInspections(projectId, work.id),
      getQualityInspectionCapabilities(projectId, work.project_area_id),
    ]);

  const [canReportProgress, canConfirmProgress] = await Promise.all([
    canReportWorkProgress(projectId, work.project_area_id),
    canConfirmWorkProgress(projectId, work.project_area_id),
  ]);
  const progressTotals = getWorkProgressTotals(work.progress);
  const candidates = capabilities.canAssignWork
    ? await getWorkAssignmentCandidates(projectId)
    : [];
  const activeBlockers = blockers.filter(
    (blocker) => blocker.status === "OPEN",
  );
  const resolvedBlockers = blockers.filter(
    (blocker) => blocker.status === "RESOLVED",
  );
  const availableActions = getWorkLifecycleActions(work.status, capabilities, {
    activeBlockerCount: activeBlockers.length,
    isReady: readiness.isReady,
  });
  const lifecycleUnavailableReasons =
    (work.status === "PLANNED" || work.status === "READY") && !readiness.isReady
      ? getReadinessFailureMessages(readiness)
      : work.status === "IN_PROGRESS" &&
          capabilities.canBlockWork &&
          activeBlockers.length === 0
        ? ["Сначала добавьте активную блокировку."]
        : work.status === "BLOCKED" && activeBlockers.length > 0
          ? activeBlockers.map(
              (blocker) => `Не устранена блокировка «${blocker.title}».`,
            )
          : [];
  const activeQuality = qualityHistory.find(
    (request) =>
      request.status === "REQUESTED" ||
      (request.inspection !== null && request.inspection.status !== "ACCEPTED"),
  );

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

      <section className="mt-6 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-lg font-semibold text-slate-950">
            Готовность к работе
          </h2>
          <span
            className={`rounded-full px-3 py-1 text-sm font-semibold ${
              readiness.isReady
                ? "bg-emerald-100 text-emerald-800"
                : "bg-red-100 text-red-800"
            }`}
          >
            {readiness.isReady ? "Готова" : "Не готова"}
          </span>
        </div>
        <ul className="mt-4 space-y-3">
          {readiness.checks.map((check) => (
            <li
              className={`rounded-xl border p-3 ${
                check.passed
                  ? "border-emerald-200 bg-emerald-50"
                  : "border-red-200 bg-red-50"
              }`}
              key={check.key}
            >
              <p className="font-medium text-slate-900">
                {check.passed ? "✓" : "✕"} {check.message}
              </p>
              {check.items.length > 0 ? (
                <ul className="mt-2 space-y-1 pl-6 text-sm text-slate-700">
                  {check.items.map((item) => (
                    <li className="list-disc" key={item.id}>
                      {check.key === "dependencies"
                        ? `${item.code ?? "Работа"} · ${item.title} · ${item.status}`
                        : `${
                            workBlockerCategoryLabels[
                              item.category as WorkBlockerCategory
                            ] ?? item.category
                          } · ${item.title}`}
                    </li>
                  ))}
                </ul>
              ) : null}
            </li>
          ))}
        </ul>
      </section>

      <WorkLifecycleControls
        availableActions={availableActions}
        projectId={projectId}
        unavailableReasons={lifecycleUnavailableReasons}
        workId={work.id}
      />

      <section className="mt-6 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-slate-950">
              Контроль качества
            </h2>
            <p className="mt-1 text-sm text-slate-600">
              Вызов, проверка и положительное решение строительного контроля.
            </p>
          </div>
          {work.status === "READY_FOR_INSPECTION" &&
          qualityCapabilities.canRequest &&
          !activeQuality ? (
            <RequestInspectionControl projectId={projectId} workId={work.id} />
          ) : null}
        </div>

        {qualityHistory.length === 0 ? (
          <p className="mt-4 text-sm text-slate-600">
            Вызов строительного контроля ещё не создан.
          </p>
        ) : (
          <ol className="mt-4 space-y-4">
            {qualityHistory.map((request) => {
              const inspection = request.inspection;
              const isInspector =
                inspection?.inspector_project_member_id ===
                qualityCapabilities.ownProjectMemberId;
              return (
                <li
                  className="rounded-2xl border border-slate-200 p-4"
                  key={request.id}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-slate-950">
                        {inspection
                          ? (inspectionStatusLabels[inspection.status] ??
                            inspection.status)
                          : (inspectionRequestStatusLabels[request.status] ??
                            request.status)}
                      </p>
                      <p className="mt-1 text-xs text-slate-600">
                        Вызвал {request.requestedByLabel} ·{" "}
                        {formatDateTime(request.requested_at)}
                      </p>
                    </div>
                    {request.status === "REQUESTED" &&
                    qualityCapabilities.canPerform ? (
                      <ScheduleInspectionControl
                        inspectionRequestId={request.id}
                        projectId={projectId}
                        workId={work.id}
                      />
                    ) : null}
                  </div>
                  {inspection ? (
                    <div className="mt-3 border-t border-slate-100 pt-3">
                      <p className="text-sm text-slate-700">
                        Инспектор: {inspection.inspectorLabel}
                      </p>
                      <p className="mt-1 text-xs text-slate-600">
                        Запланировано {formatDateTime(inspection.scheduled_at)}
                        {inspection.started_at
                          ? ` · начато ${formatDateTime(inspection.started_at)}`
                          : ""}
                        {inspection.accepted_at
                          ? ` · принято ${formatDateTime(inspection.accepted_at)}`
                          : ""}
                      </p>
                      {inspection.result_note ? (
                        <p className="mt-3 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-900">
                          Результат: {inspection.result_note}
                        </p>
                      ) : null}
                      {inspection.status === "SCHEDULED" &&
                      qualityCapabilities.canPerform &&
                      isInspector ? (
                        <div className="mt-4">
                          <StartInspectionControl
                            inspectionId={inspection.id}
                            projectId={projectId}
                            workId={work.id}
                          />
                        </div>
                      ) : null}
                      {inspection.status === "IN_INSPECTION" &&
                      qualityCapabilities.canAccept &&
                      isInspector ? (
                        <AcceptInspectionControl
                          inspectionId={inspection.id}
                          projectId={projectId}
                          workId={work.id}
                        />
                      ) : null}
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ol>
        )}
      </section>

      <section className="mt-6 rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-lg font-semibold text-slate-950">Блокировки</h2>
        {capabilities.canBlockWork &&
        !["ACCEPTED", "CLOSED", "CANCELLED", "PAUSED"].includes(work.status) ? (
          <OpenWorkBlockerControl projectId={projectId} workId={work.id} />
        ) : null}
        <div className="mt-5 grid gap-5 lg:grid-cols-2">
          <div>
            <h3 className="font-semibold text-slate-950">Активные</h3>
            {activeBlockers.length === 0 ? (
              <p className="mt-2 text-sm text-slate-600">
                Активных блокировок нет.
              </p>
            ) : (
              <ol className="mt-3 space-y-3">
                {activeBlockers.map((blocker) => (
                  <li
                    className="rounded-xl border border-amber-200 bg-amber-50 p-4"
                    key={blocker.id}
                  >
                    <div className="flex flex-wrap justify-between gap-3">
                      <div>
                        <p className="text-xs font-bold uppercase tracking-wide text-amber-800">
                          {workBlockerCategoryLabels[
                            blocker.category as WorkBlockerCategory
                          ] ?? blocker.category}
                        </p>
                        <p className="mt-1 font-semibold text-slate-950">
                          {blocker.title}
                        </p>
                      </div>
                      <span className="text-sm font-semibold text-amber-800">
                        {workBlockerStatusLabels.OPEN}
                      </span>
                    </div>
                    <p className="mt-2 text-sm leading-6 text-slate-700">
                      {blocker.description}
                    </p>
                    <p className="mt-2 text-xs text-slate-600">
                      Открыл {blocker.openedByLabel} ·{" "}
                      {formatDateTime(blocker.opened_at)}
                    </p>
                    {capabilities.canBlockWork ? (
                      <ResolveWorkBlockerControl
                        projectId={projectId}
                        workBlockerId={blocker.id}
                        workId={work.id}
                      />
                    ) : null}
                  </li>
                ))}
              </ol>
            )}
          </div>
          <div>
            <h3 className="font-semibold text-slate-950">История</h3>
            {resolvedBlockers.length === 0 ? (
              <p className="mt-2 text-sm text-slate-600">
                Устранённых блокировок нет.
              </p>
            ) : (
              <ol className="mt-3 space-y-3">
                {resolvedBlockers.map((blocker) => (
                  <li
                    className="rounded-xl border border-slate-200 p-4"
                    key={blocker.id}
                  >
                    <div className="flex flex-wrap justify-between gap-3">
                      <div>
                        <p className="text-xs font-bold uppercase tracking-wide text-slate-600">
                          {workBlockerCategoryLabels[
                            blocker.category as WorkBlockerCategory
                          ] ?? blocker.category}
                        </p>
                        <p className="mt-1 font-semibold text-slate-950">
                          {blocker.title}
                        </p>
                      </div>
                      <span className="text-sm font-semibold text-emerald-700">
                        {workBlockerStatusLabels.RESOLVED}
                      </span>
                    </div>
                    <p className="mt-2 text-sm leading-6 text-slate-700">
                      {blocker.description}
                    </p>
                    <p className="mt-2 text-xs text-slate-600">
                      Открыл {blocker.openedByLabel} ·{" "}
                      {formatDateTime(blocker.opened_at)}
                    </p>
                    <p className="mt-2 text-sm text-slate-700">
                      Результат: {blocker.resolution_note}
                    </p>
                    <p className="mt-1 text-xs text-slate-600">
                      Устранил {blocker.resolvedByLabel} ·{" "}
                      {formatDateTime(blocker.resolved_at)}
                    </p>
                  </li>
                ))}
              </ol>
            )}
          </div>
        </div>
      </section>

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
        <p className="mt-4 min-w-0 break-words text-base font-semibold text-slate-950 [overflow-wrap:anywhere]">
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
                    <p className="break-words font-semibold text-slate-950 [overflow-wrap:anywhere]">
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
                {entry.daily_report_id ? (
                  <Link
                    className="mt-3 block text-sm text-emerald-800 underline"
                    href={`/app/projects/${projectId}/daily-reports/${entry.daily_report_id}`}
                  >
                    Дневной отчёт — решение по всему отчёту
                  </Link>
                ) : null}
                {canConfirmProgress &&
                !entry.daily_report_id &&
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
