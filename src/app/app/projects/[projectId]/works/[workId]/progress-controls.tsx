"use client";

import { useActionState, useState } from "react";

import {
  confirmWorkProgress,
  reportWorkProgress,
  returnWorkProgress,
  type WorkProgressActionState,
  type WorkProgressDecisionActionState,
} from "../actions";

export function WorkProgressControls({
  projectId,
  workId,
}: {
  projectId: string;
  workId: string;
}) {
  const [state, formAction, pending] = useActionState<
    WorkProgressActionState,
    FormData
  >(reportWorkProgress.bind(null, projectId, workId), {});
  return (
    <form action={formAction} className="mt-4 grid gap-3 sm:grid-cols-2">
      <label className="text-sm font-medium text-slate-800">
        Выполненный объём
        <input
          aria-label="Выполненный объём"
          className="mt-1 min-h-11 w-full rounded-xl border border-slate-300 px-3"
          name="quantity"
          required
          step="any"
          type="number"
        />
        {state.fieldErrors?.quantity?.map((message) => (
          <span className="mt-1 block text-sm text-red-700" key={message}>
            {message}
          </span>
        ))}
      </label>
      <label className="text-sm font-medium text-slate-800">
        Дата фиксации
        <input
          className="mt-1 min-h-11 w-full rounded-xl border border-slate-300 px-3"
          name="recordedForDate"
          type="date"
        />
      </label>
      <label className="text-sm font-medium text-slate-800 sm:col-span-2">
        Примечание
        <textarea
          className="mt-1 min-h-20 w-full rounded-xl border border-slate-300 px-3 py-2"
          name="note"
        />
      </label>
      <div className="sm:col-span-2">
        <button
          className="min-h-11 rounded-xl bg-emerald-700 px-4 text-sm font-semibold text-white disabled:opacity-60"
          disabled={pending}
          type="submit"
        >
          {pending ? "Сохраняется…" : "Добавить выполненный объём"}
        </button>
        {state.message ? (
          <p className="mt-2 text-sm text-red-700" role="alert">
            {state.message}
          </p>
        ) : null}
      </div>
    </form>
  );
}

export function WorkProgressDecisionControls({
  projectId,
  workId,
  workProgressEntryId,
}: {
  projectId: string;
  workId: string;
  workProgressEntryId: string;
}) {
  const [isReturnFormOpen, setIsReturnFormOpen] = useState(false);
  const [confirmState, confirmAction, confirming] = useActionState<
    WorkProgressDecisionActionState,
    FormData
  >(confirmWorkProgress.bind(null, projectId, workId, workProgressEntryId), {});
  const [returnState, returnAction, returning] = useActionState<
    WorkProgressDecisionActionState,
    FormData
  >(returnWorkProgress.bind(null, projectId, workId, workProgressEntryId), {});

  return (
    <div className="mt-4 border-t border-slate-200 pt-4">
      <div className="flex flex-wrap gap-2">
        <form action={confirmAction}>
          <button
            className="min-h-10 rounded-xl bg-emerald-700 px-3 text-sm font-semibold text-white disabled:opacity-60"
            disabled={confirming || returning}
            type="submit"
          >
            {confirming ? "Подтверждается…" : "Подтвердить"}
          </button>
        </form>
        <button
          className="min-h-10 rounded-xl border border-amber-700 px-3 text-sm font-semibold text-amber-900 disabled:opacity-60"
          disabled={confirming || returning}
          onClick={() => setIsReturnFormOpen((open) => !open)}
          type="button"
        >
          Вернуть
        </button>
      </div>
      {confirmState.message ? (
        <p className="mt-2 text-sm text-red-700" role="alert">
          {confirmState.message}
        </p>
      ) : null}
      {isReturnFormOpen ? (
        <form action={returnAction} className="mt-3 grid gap-2">
          <label className="text-sm font-medium text-slate-800">
            Причина возврата
            <textarea
              aria-label="Причина возврата"
              className="mt-1 min-h-20 w-full rounded-xl border border-slate-300 px-3 py-2"
              name="reason"
              required
            />
          </label>
          {returnState.fieldErrors?.reason?.map((message) => (
            <span className="text-sm text-red-700" key={message}>
              {message}
            </span>
          ))}
          <div>
            <button
              className="min-h-10 rounded-xl bg-amber-700 px-3 text-sm font-semibold text-white disabled:opacity-60"
              disabled={returning || confirming}
              type="submit"
            >
              {returning ? "Возвращается…" : "Вернуть запись"}
            </button>
          </div>
          {returnState.message ? (
            <p className="text-sm text-red-700" role="alert">
              {returnState.message}
            </p>
          ) : null}
        </form>
      ) : null}
    </div>
  );
}
