"use client";

import { useActionState } from "react";
import { reportWorkProgress, type WorkProgressActionState } from "../actions";

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
