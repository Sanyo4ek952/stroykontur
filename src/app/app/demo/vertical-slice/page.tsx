import type { Metadata } from "next";
import Link from "next/link";

import { getOwnVerticalSlice } from "@/modules/acknowledgements/server/queries";
import { requireUser } from "@/server/auth/require-user";

import { ActionForm } from "./action-form";
import { acknowledgeDocumentImpact, markNotificationRead } from "./actions";

export const metadata: Metadata = { title: "Вертикальный срез" };

const actionLabels: Record<string, string> = {
  "document.issue_for_work": "Ревизия выдана в производство",
  "document.issue_withdrawn": "Выдача ревизии отозвана",
  "document_impact.detected": "Обнаружено влияние на работу",
  "task.created": "Создана задача ответственному",
  "notification.read": "Уведомление прочитано",
  "document_impact.acknowledged": "Ознакомление подтверждено",
};

const dateFormatter = new Intl.DateTimeFormat("ru-RU", {
  dateStyle: "medium",
  timeStyle: "short",
});

function formatDate(value: string | null) {
  return value ? dateFormatter.format(new Date(value)) : "—";
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-semibold tracking-wide text-slate-500 uppercase">
        {label}
      </dt>
      <dd className="mt-1 text-sm leading-6 font-medium text-slate-900">
        {value}
      </dd>
    </div>
  );
}

function Card({
  children,
  eyebrow,
  title,
}: {
  children: React.ReactNode;
  eyebrow: string;
  title: string;
}) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
      <p className="text-xs font-semibold tracking-[0.14em] text-emerald-700 uppercase">
        {eyebrow}
      </p>
      <h2 className="mt-2 text-xl font-semibold tracking-tight text-slate-950">
        {title}
      </h2>
      <div className="mt-5">{children}</div>
    </section>
  );
}

export default async function VerticalSlicePage() {
  await requireUser();
  const data = await getOwnVerticalSlice();

  if (!data) {
    return (
      <main className="mx-auto min-h-dvh w-full max-w-3xl px-5 py-8 sm:px-8">
        <Card eyebrow="Демо" title="Сценарий не найден">
          <p className="text-sm leading-6 text-slate-600">
            Выполните локальную подготовку данных командой
            <code className="ml-1 rounded bg-slate-100 px-1.5 py-1">
              pnpm demo:seed
            </code>
            .
          </p>
        </Card>
      </main>
    );
  }

  const { history, notificationId, scenario } = data;
  const isRead = Boolean(scenario.notification_read_at);
  const isAcknowledged = Boolean(scenario.acknowledgement_id);

  return (
    <main className="mx-auto min-h-dvh w-full max-w-5xl px-4 py-6 sm:px-8 sm:py-10">
      <header className="mb-7 rounded-3xl bg-slate-950 p-6 text-white sm:p-8">
        <p className="text-xs font-semibold tracking-[0.16em] text-emerald-300 uppercase">
          TASK-012 · реальные данные local Supabase
        </p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
          Изменение документации → ознакомление
        </h1>
        <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-300 sm:text-base">
          Первый сквозной сценарий: документ влияет на назначенную работу,
          система создаёт задачу и уведомление, а ответственный отдельно читает
          его и подтверждает ознакомление.
        </p>
        <Link
          className="mt-5 inline-flex text-sm font-medium text-white underline decoration-slate-500 underline-offset-4 hover:decoration-white"
          href="/app"
        >
          ← В защищённую область
        </Link>
      </header>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card eyebrow="Проект" title={scenario.project_name}>
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail label="Код" value={scenario.project_code} />
            <Detail
              label="Контекст роли"
              value={scenario.member_role_codes ?? "—"}
            />
          </dl>
        </Card>

        <Card eyebrow="Технический документ" title={scenario.document_title}>
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail label="Шифр" value={scenario.document_code} />
            <Detail
              label="Ревизия"
              value={`${scenario.revision_code} · ${scenario.revision_status}`}
            />
            <Detail label="Выдача" value={scenario.issue_state} />
            <Detail label="Выдано" value={formatDate(scenario.issued_at)} />
          </dl>
        </Card>

        <Card eyebrow="Затронутая работа" title={scenario.work_title}>
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail label="Код" value={scenario.work_code} />
            <Detail label="Статус" value={scenario.work_status} />
            <Detail label="Ответственный" value={scenario.responsible_email} />
          </dl>
        </Card>

        <Card eyebrow="DocumentImpact" title="Влияние новой ревизии">
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail label="Статус" value={scenario.impact_status} />
            <Detail
              label="Обнаружено"
              value={formatDate(scenario.detected_at)}
            />
          </dl>
        </Card>

        <Card eyebrow="Task" title="Проверить влияние документа">
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail label="Тип" value={scenario.task_type} />
            <Detail label="Статус" value={scenario.task_status} />
            <Detail label="Исполнитель" value={scenario.responsible_email} />
          </dl>
        </Card>

        <Card
          eyebrow="Notification"
          title={isRead ? "Прочитано" : "Не прочитано"}
        >
          <dl className="grid gap-4 sm:grid-cols-2">
            <Detail
              label="Доставлено"
              value={formatDate(scenario.notification_created_at)}
            />
            <Detail
              label="Прочитано"
              value={formatDate(scenario.notification_read_at)}
            />
          </dl>
          {!isRead ? (
            <ActionForm
              action={markNotificationRead}
              label="Отметить прочитанным"
              notificationId={notificationId}
              pendingLabel="Отмечаем…"
            />
          ) : null}
        </Card>

        <Card
          eyebrow="Acknowledgement"
          title={
            isAcknowledged
              ? "Ознакомление подтверждено"
              : "Ожидает подтверждения"
          }
        >
          <p className="text-sm leading-6 text-slate-600">
            Подтверждение фиксирует осведомлённость ответственного. Оно не
            закрывает Task и не переводит DocumentImpact в RESOLVED.
          </p>
          {isAcknowledged ? (
            <p className="mt-4 text-sm font-medium text-emerald-700">
              Подтверждено {formatDate(scenario.acknowledged_at)}
            </p>
          ) : isRead ? (
            <ActionForm
              action={acknowledgeDocumentImpact}
              label="Подтвердить ознакомление"
              notificationId={notificationId}
              pendingLabel="Подтверждаем…"
            />
          ) : (
            <p className="mt-4 text-sm font-medium text-amber-700">
              Сначала отметьте уведомление прочитанным.
            </p>
          )}
        </Card>

        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6 lg:col-span-2">
          <p className="text-xs font-semibold tracking-[0.14em] text-emerald-700 uppercase">
            История
          </p>
          <h2 className="mt-2 text-xl font-semibold tracking-tight text-slate-950">
            AuditEntry этого сценария
          </h2>
          <ol className="mt-5 space-y-4">
            {history.map((entry, index) => (
              <li
                className="flex gap-3"
                key={`${entry.action_key}-${entry.occurred_at}`}
              >
                <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-slate-950 text-xs font-semibold text-white">
                  {index + 1}
                </span>
                <div>
                  <p className="text-sm font-medium text-slate-900">
                    {actionLabels[entry.action_key] ?? entry.action_key}
                  </p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    {formatDate(entry.occurred_at)}
                  </p>
                </div>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </main>
  );
}
