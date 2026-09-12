import type { Metadata } from "next";

import {
  getOwnProjectNotifications,
  getOwnProjectTasks,
} from "@/modules/application/server/queries";

import { getTaskTypeLabel } from "../../status-labels";
import {
  Detail,
  EmptyState,
  formatDateTime,
  PageIntro,
  StatusBadge,
} from "../ui";

export const metadata: Metadata = { title: "Мои задачи" };

export default async function ProjectTasksPage({
  params,
}: PageProps<"/app/projects/[projectId]/tasks">) {
  const { projectId } = await params;
  const [tasks, notifications] = await Promise.all([
    getOwnProjectTasks(projectId),
    getOwnProjectNotifications(projectId),
  ]);
  const impactContexts = notifications
    .map((notification) => notification.scenario)
    .filter((scenario) => scenario !== null);

  return (
    <>
      <PageIntro
        description="Только задачи, назначенные вашему активному участнику проекта."
        eyebrow="Задачи"
        title="Мои задачи"
      />
      {tasks.length === 0 ? (
        <EmptyState title="Нет назначенных задач." />
      ) : (
        <ul className="space-y-3">
          {tasks.map((task) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-5"
              key={task.id}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <h2 className="text-lg font-semibold text-slate-950">
                  {getTaskTypeLabel(task.task_type)}
                </h2>
                <StatusBadge status={task.status} />
              </div>
              <p className="mt-3 text-sm text-slate-500">
                Создано {formatDateTime(task.created_at)}
              </p>
            </li>
          ))}
        </ul>
      )}

      {impactContexts.length > 0 ? (
        <section className="mt-7">
          <h2 className="text-lg font-semibold text-slate-950">
            Связанный контекст изменений
          </h2>
          <p className="mt-1 mb-3 text-sm text-slate-600">
            Контекст разрешён через существующую связь task_document_impacts.
          </p>
          <div className="grid gap-3">
            {impactContexts.map((scenario) => (
              <dl
                className="grid gap-4 rounded-2xl border border-amber-200 bg-amber-50 p-5 sm:grid-cols-3"
                key={
                  scenario.document_code +
                  scenario.revision_code +
                  scenario.work_code
                }
              >
                <Detail label="Документ">
                  {scenario.document_code} · {scenario.revision_code}
                </Detail>
                <Detail label="Работа">
                  {scenario.work_code} · {scenario.work_title}
                </Detail>
                <Detail label="Влияние">
                  <StatusBadge status={scenario.impact_status} />
                </Detail>
              </dl>
            ))}
          </div>
        </section>
      ) : null}
    </>
  );
}
