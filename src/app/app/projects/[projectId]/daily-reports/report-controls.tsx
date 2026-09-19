"use client";
import { useActionState } from "react";
import {
  createDailyReport,
  updateDailyReportDraft,
  addDailyReportProgress,
  submitDailyReport,
  confirmDailyReport,
  returnDailyReport,
  type DailyReportActionState,
} from "./actions";

const fieldClass =
  "mt-1 block min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3 py-2";
const buttonClass =
  "min-h-11 rounded-xl bg-emerald-800 px-4 py-2 font-semibold text-white disabled:opacity-50";
function Message({ state }: { state: DailyReportActionState }) {
  return state.message ? (
    <p role="alert" className="text-sm text-red-800">
      {state.message}
    </p>
  ) : null;
}
export function DailyReportForm({
  projectId,
  reportId,
  commandId,
  areas = [],
  initial,
}: {
  projectId: string;
  reportId?: string;
  commandId: string;
  areas?: { id: string; code: string; name: string }[];
  initial?: {
    workers_count: number;
    summary: string | null;
    problems: string | null;
  };
}) {
  const action = reportId
    ? updateDailyReportDraft.bind(null, projectId, reportId)
    : createDailyReport.bind(null, projectId);
  const [state, formAction, pending] = useActionState(action, {});
  return (
    <form
      action={formAction}
      className="mt-4 space-y-4 rounded-2xl border border-slate-200 bg-white p-5"
    >
      <input
        type="hidden"
        name="commandId"
        value={state.nextCommandId ?? commandId}
      />
      {!reportId && (
        <>
          <label className="block">
            Зона
            <select
              className={fieldClass}
              name="projectAreaId"
              required
              defaultValue={areas[0]?.id}
            >
              {areas.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.code} · {a.name}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            Дата отчёта
            <input
              className={fieldClass}
              type="date"
              name="reportDate"
              required
            />
          </label>
        </>
      )}
      <label className="block">
        Количество работников
        <input
          className={fieldClass}
          type="number"
          name="workersCount"
          min="0"
          max="100000"
          step="1"
          defaultValue={initial?.workers_count ?? 0}
          required
        />
      </label>
      <label className="block">
        Выполненные работы
        <textarea
          className={fieldClass}
          name="summary"
          maxLength={4000}
          defaultValue={initial?.summary ?? ""}
        />
      </label>
      <label className="block">
        Проблемы
        <textarea
          className={fieldClass}
          name="problems"
          maxLength={4000}
          defaultValue={initial?.problems ?? ""}
        />
      </label>
      <Message state={state} />
      <button className={buttonClass} disabled={pending} type="submit">
        {pending
          ? "Сохранение…"
          : reportId
            ? "Сохранить черновик"
            : "Создать отчёт"}
      </button>
    </form>
  );
}
export function DailyReportProgressForm({
  projectId,
  reportId,
  commandId,
  works,
}: {
  projectId: string;
  reportId: string;
  commandId: string;
  works: { id: string; code: string; title: string; unit: string | null }[];
}) {
  const [state, action, pending] = useActionState(
    addDailyReportProgress.bind(null, projectId, reportId),
    {},
  );
  return (
    <form
      action={action}
      className="mt-4 space-y-4 rounded-2xl border border-slate-200 bg-white p-5"
    >
      <h2 className="text-lg font-semibold">Добавить объём в отчёт</h2>
      <input
        type="hidden"
        name="commandId"
        value={state.nextCommandId ?? commandId}
      />
      <label className="block">
        Работа
        <select className={fieldClass} name="workId" required defaultValue="">
          <option value="" disabled>
            Выберите работу
          </option>
          {works.map((w) => (
            <option key={w.id} value={w.id}>
              {w.code} · {w.title} ({w.unit})
            </option>
          ))}
        </select>
      </label>
      <label className="block">
        Выполненный объём
        <input
          className={fieldClass}
          name="quantity"
          type="number"
          min="0.000001"
          step="any"
          required
        />
      </label>
      <label className="block">
        Примечание
        <textarea className={fieldClass} name="note" maxLength={2000} />
      </label>
      <Message state={state} />
      <button
        className={buttonClass}
        disabled={pending || works.length === 0}
        type="submit"
      >
        {pending ? "Добавление…" : "Добавить объём"}
      </button>
    </form>
  );
}
export function DailyReportSubmit({
  projectId,
  reportId,
  commandId,
}: {
  projectId: string;
  reportId: string;
  commandId: string;
}) {
  const [state, action, pending] = useActionState(
    submitDailyReport.bind(null, projectId, reportId),
    {},
  );
  return (
    <form action={action} className="mt-4 space-y-3">
      <input type="hidden" name="commandId" value={commandId} />
      <Message state={state} />
      <button className={buttonClass} disabled={pending} type="submit">
        Отправить на подтверждение
      </button>
    </form>
  );
}
export function DailyReportDecision({
  projectId,
  reportId,
  confirmCommandId,
  returnCommandId,
}: {
  projectId: string;
  reportId: string;
  confirmCommandId: string;
  returnCommandId: string;
}) {
  const [confirmed, confirmAction, confirming] = useActionState(
    confirmDailyReport.bind(null, projectId, reportId),
    {},
  );
  const [returned, returnAction, returning] = useActionState(
    returnDailyReport.bind(null, projectId, reportId),
    {},
  );
  return (
    <section className="mt-6 space-y-4 rounded-2xl border border-slate-200 bg-white p-5">
      <h2 className="text-lg font-semibold">Решение по всему отчёту</h2>
      <form action={confirmAction} className="space-y-3">
        <input type="hidden" name="commandId" value={confirmCommandId} />
        <Message state={confirmed} />
        <button
          className={buttonClass}
          type="submit"
          disabled={confirming || returning}
        >
          Подтвердить отчёт
        </button>
      </form>
      <form action={returnAction} className="space-y-3">
        <input type="hidden" name="commandId" value={returnCommandId} />
        <label className="block">
          Причина возврата
          <textarea
            className={fieldClass}
            name="reason"
            maxLength={2000}
            required
          />
        </label>
        <Message state={returned} />
        <button
          className={buttonClass}
          type="submit"
          disabled={confirming || returning}
        >
          Вернуть отчёт
        </button>
      </form>
    </section>
  );
}
