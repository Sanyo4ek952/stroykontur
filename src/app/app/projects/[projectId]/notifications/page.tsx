import type { Metadata } from "next";

import { getOwnProjectNotifications } from "@/modules/application/server/queries";
import { ActionForm } from "@/app/app/demo/vertical-slice/action-form";
import {
  acknowledgeDocumentImpact,
  markNotificationRead,
} from "@/app/app/demo/vertical-slice/actions";

import {
  Detail,
  EmptyState,
  formatDateTime,
  PageIntro,
  StatusBadge,
} from "../ui";

export const metadata: Metadata = { title: "Уведомления" };

export default async function ProjectNotificationsPage({
  params,
}: PageProps<"/app/projects/[projectId]/notifications">) {
  const { projectId } = await params;
  const notifications = await getOwnProjectNotifications(projectId);

  return (
    <>
      <PageIntro
        description="Только уведомления вашего активного участника проекта. Прочтение и ознакомление фиксируются отдельно."
        eyebrow="Входящие"
        title="Уведомления"
      />
      {notifications.length === 0 ? (
        <EmptyState title="Новых уведомлений нет." />
      ) : (
        <ul className="space-y-4">
          {notifications.map((notification) => {
            const scenario = notification.scenario;
            const isRead = Boolean(notification.read_at);
            const isAcknowledged = Boolean(scenario?.acknowledgement_id);

            return (
              <li
                className={
                  "rounded-2xl border bg-white p-5 " +
                  (isRead ? "border-slate-200" : "border-emerald-300")
                }
                key={notification.id}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-bold tracking-wide text-emerald-700 uppercase">
                      {isRead ? "Прочитано" : "Новое уведомление"}
                    </p>
                    <h2 className="mt-1 text-lg font-semibold text-slate-950">
                      {scenario?.task_type === "document_impact_review"
                        ? "Изменение документации влияет на работу"
                        : "Событие проекта"}
                    </h2>
                  </div>
                  <span className="text-xs text-slate-500">
                    {formatDateTime(notification.created_at)}
                  </span>
                </div>

                {scenario ? (
                  <dl className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                    <Detail label="Задача">
                      <StatusBadge status={scenario.task_status} />
                    </Detail>
                    <Detail label="Документ">
                      {scenario.document_code} · {scenario.revision_code}
                    </Detail>
                    <Detail label="Работа">{scenario.work_code}</Detail>
                    <Detail label="Ознакомление">
                      {isAcknowledged ? "Подтверждено" : "Ожидается"}
                    </Detail>
                  </dl>
                ) : null}

                {!isRead ? (
                  <ActionForm
                    action={markNotificationRead}
                    label="Отметить прочитанным"
                    notificationId={notification.id}
                    pendingLabel="Отмечаем…"
                  />
                ) : !isAcknowledged && scenario ? (
                  <ActionForm
                    action={acknowledgeDocumentImpact}
                    label="Подтвердить ознакомление"
                    notificationId={notification.id}
                    pendingLabel="Подтверждаем…"
                  />
                ) : isAcknowledged ? (
                  <p className="mt-4 text-sm font-semibold text-emerald-700">
                    Ознакомление подтверждено
                  </p>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}
