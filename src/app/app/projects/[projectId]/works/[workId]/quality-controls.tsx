"use client";

import { useActionState } from "react";

import {
  acceptWorkInspection,
  requestWorkInspection,
  scheduleWorkInspection,
  startWorkInspection,
  type QualityInspectionActionState,
} from "./quality-actions";

function ActionButton({
  action,
  label,
}: {
  action: (
    state: QualityInspectionActionState,
    formData: FormData,
  ) => Promise<QualityInspectionActionState>;
  label: string;
}) {
  const [state, formAction, pending] = useActionState(action, {});
  return (
    <form action={formAction}>
      <button
        className="rounded-xl bg-emerald-700 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-800 disabled:cursor-wait disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending ? "Выполняется…" : label}
      </button>
      {state.message ? (
        <p className="mt-2 text-sm font-medium text-red-700" role="alert">
          {state.message}
        </p>
      ) : null}
    </form>
  );
}

export function RequestInspectionControl({
  projectId,
  workId,
}: {
  projectId: string;
  workId: string;
}) {
  return (
    <ActionButton
      action={requestWorkInspection.bind(null, projectId, workId)}
      label="Вызвать строительный контроль"
    />
  );
}

export function ScheduleInspectionControl({
  inspectionRequestId,
  projectId,
  workId,
}: {
  inspectionRequestId: string;
  projectId: string;
  workId: string;
}) {
  return (
    <ActionButton
      action={scheduleWorkInspection.bind(
        null,
        projectId,
        workId,
        inspectionRequestId,
      )}
      label="Принять вызов"
    />
  );
}

export function StartInspectionControl({
  inspectionId,
  projectId,
  workId,
}: {
  inspectionId: string;
  projectId: string;
  workId: string;
}) {
  return (
    <ActionButton
      action={startWorkInspection.bind(null, projectId, workId, inspectionId)}
      label="Начать проверку"
    />
  );
}

export function AcceptInspectionControl({
  inspectionId,
  projectId,
  workId,
}: {
  inspectionId: string;
  projectId: string;
  workId: string;
}) {
  const [state, formAction, pending] = useActionState(
    acceptWorkInspection.bind(null, projectId, workId, inspectionId),
    {},
  );
  return (
    <form action={formAction} className="mt-4 grid gap-3">
      <label className="grid gap-1 text-sm font-medium text-slate-800">
        Результат проверки
        <textarea
          className="min-h-24 rounded-xl border border-slate-300 px-3 py-2"
          maxLength={2000}
          name="resultNote"
          required
        />
      </label>
      {state.fieldErrors?.resultNote?.map((message) => (
        <p className="text-sm text-red-700" key={message} role="alert">
          {message}
        </p>
      ))}
      {state.message ? (
        <p className="text-sm font-medium text-red-700" role="alert">
          {state.message}
        </p>
      ) : null}
      <button
        className="w-fit rounded-xl bg-emerald-700 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-800 disabled:cursor-wait disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending ? "Принимаем…" : "Принять качество работы"}
      </button>
    </form>
  );
}
