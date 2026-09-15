"use client";

import { useActionState } from "react";

import {
  workBlockerCategories,
  workBlockerCategoryLabels,
} from "@/modules/works/model/readiness";

import {
  openWorkBlocker,
  resolveWorkBlocker,
  type WorkBlockerActionState,
} from "../actions";

function FieldError({ messages }: { messages?: string[] }) {
  return messages?.map((message) => (
    <p className="mt-1 text-sm font-medium text-red-700" key={message}>
      {message}
    </p>
  ));
}
export function OpenWorkBlockerControl({
  projectId,
  workId,
}: {
  projectId: string;
  workId: string;
}) {
  const [state, action, pending] = useActionState<
    WorkBlockerActionState,
    FormData
  >(openWorkBlocker.bind(null, projectId, workId), {});
  return (
    <details className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4">
      <summary className="cursor-pointer font-semibold text-amber-950">
        Добавить блокировку
      </summary>
      <form action={action} className="mt-4 grid gap-4">
        <label className="grid gap-1 text-sm font-medium text-slate-800">
          Категория
          <select
            className="rounded-lg border border-slate-300 bg-white px-3 py-2"
            name="category"
            required
          >
            {workBlockerCategories.map((category) => (
              <option key={category} value={category}>
                {workBlockerCategoryLabels[category]}
              </option>
            ))}
          </select>
          <FieldError messages={state.fieldErrors?.category} />
        </label>
        <label className="grid gap-1 text-sm font-medium text-slate-800">
          Название
          <input
            className="rounded-lg border border-slate-300 bg-white px-3 py-2"
            maxLength={200}
            name="title"
            required
          />
          <FieldError messages={state.fieldErrors?.title} />
        </label>
        <label className="grid gap-1 text-sm font-medium text-slate-800">
          Описание
          <textarea
            className="min-h-24 rounded-lg border border-slate-300 bg-white px-3 py-2"
            maxLength={4000}
            name="description"
            required
          />
          <FieldError messages={state.fieldErrors?.description} />
        </label>
        <button
          className="w-fit rounded-xl bg-amber-700 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-800 disabled:cursor-wait disabled:opacity-60"
          disabled={pending}
          type="submit"
        >
          {pending ? "Сохраняется…" : "Открыть блокировку"}
        </button>
        {state.message ? (
          <p className="text-sm font-medium text-red-700" role="alert">
            {state.message}
          </p>
        ) : null}
      </form>
    </details>
  );
}

export function ResolveWorkBlockerControl({
  projectId,
  workBlockerId,
  workId,
}: {
  projectId: string;
  workBlockerId: string;
  workId: string;
}) {
  const [state, action, pending] = useActionState<
    WorkBlockerActionState,
    FormData
  >(resolveWorkBlocker.bind(null, projectId, workId, workBlockerId), {});
  return (
    <details className="mt-3">
      <summary className="cursor-pointer text-sm font-semibold text-emerald-800">
        Устранить
      </summary>
      <form action={action} className="mt-3 grid gap-3">
        <label className="grid gap-1 text-sm font-medium text-slate-800">
          Результат устранения
          <textarea
            className="min-h-20 rounded-lg border border-slate-300 px-3 py-2"
            maxLength={2000}
            name="resolutionNote"
            required
          />
          <FieldError messages={state.fieldErrors?.resolutionNote} />
        </label>
        <button
          className="w-fit rounded-xl bg-emerald-700 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-800 disabled:cursor-wait disabled:opacity-60"
          disabled={pending}
          type="submit"
        >
          {pending ? "Сохраняется…" : "Подтвердить устранение"}
        </button>
        {state.message ? (
          <p className="text-sm font-medium text-red-700" role="alert">
            {state.message}
          </p>
        ) : null}
      </form>
    </details>
  );
}
