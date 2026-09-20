"use client";

import { useActionState, useState } from "react";
import { assignWork, reassignWork } from "../assignment-actions";

type Props = {
  projectId: string;
  workId: string;
  currentAssignment: { id: string; responsibleLabel: string } | null;
  candidates: { id: string; label: string; name: string; role: string }[];
};
function AssignmentForm({
  projectId,
  workId,
  currentAssignment,
  candidates,
}: Props) {
  // Kept with the captured expected assignment for the lifetime of this form.
  const [commandId] = useState(() => crypto.randomUUID());
  const [state, action, pending] = useActionState(
    currentAssignment ? reassignWork : assignWork,
    {},
  );
  return (
    <form action={action} className="mt-4 min-w-0 max-w-full space-y-4">
      <input type="hidden" name="projectId" value={projectId} />
      <input type="hidden" name="workId" value={workId} />
      <input type="hidden" name="commandId" value={commandId} />
      {currentAssignment ? (
        <>
          <input
            type="hidden"
            name="expectedCurrentAssignmentId"
            value={currentAssignment.id}
          />
          <p className="break-words text-sm leading-6 text-slate-700">
            Текущий ответственный: {currentAssignment.responsibleLabel}
          </p>
        </>
      ) : null}
      <fieldset disabled={pending || state.success}>
        <legend className="text-sm font-medium text-slate-900">
          Новый ответственный
        </legend>
        {candidates.length > 0 ? (
          <div className="mt-2 max-h-72 min-w-0 max-w-full space-y-2 overflow-x-hidden overflow-y-auto overscroll-contain rounded-xl border border-slate-200 bg-slate-50 p-2">
            {candidates.map((member) => (
              <label
                className="flex min-h-14 min-w-0 cursor-pointer items-start gap-3 rounded-lg border border-slate-200 bg-white p-3 text-left transition has-checked:border-emerald-700 has-checked:bg-emerald-50 hover:border-slate-300"
                key={member.id}
              >
                <input
                  aria-label={member.label}
                  className="mt-1 size-4 shrink-0 accent-emerald-800"
                  disabled={pending || state.success}
                  name="newProjectMemberId"
                  required
                  type="radio"
                  value={member.id}
                />
                <span className="min-w-0 flex-1">
                  <span className="block break-words font-semibold leading-5 text-slate-950 [overflow-wrap:anywhere]">
                    {member.name}
                  </span>
                  <span className="mt-1 block break-words text-sm leading-5 text-slate-600 [overflow-wrap:anywhere]">
                    {member.role}
                  </span>
                </span>
              </label>
            ))}
          </div>
        ) : (
          <p className="mt-2 text-sm text-slate-600">
            Нет доступных участников для назначения.
          </p>
        )}
      </fieldset>
      <label className="block text-sm font-medium">
        {currentAssignment
          ? "Причина переназначения"
          : "Причина назначения (необязательно)"}
        <textarea
          name="reason"
          required={Boolean(currentAssignment)}
          maxLength={2000}
          disabled={pending || state.success}
          className="mt-1 block min-h-24 w-full min-w-0 max-w-full rounded-lg border border-slate-300 p-3 text-base"
        />
      </label>
      <button
        disabled={pending || state.success || candidates.length === 0}
        className="min-h-11 w-full rounded-lg bg-emerald-800 px-4 py-2 font-semibold text-white disabled:opacity-50 sm:w-auto"
      >
        {pending ? "Сохранение…" : "Подтвердить назначение"}
      </button>
      {state.message ? <p role="status">{state.message}</p> : null}
    </form>
  );
}
export function WorkAssignmentControls(props: Props) {
  const [snapshot, setSnapshot] = useState<Props | null>(null);
  return (
    <div className="mt-4 min-w-0 max-w-full">
      <button
        type="button"
        className="min-h-11 rounded-lg px-1 font-semibold text-emerald-800 hover:underline"
        onClick={() => setSnapshot(snapshot ? null : props)}
      >
        {snapshot
          ? "Закрыть форму"
          : props.currentAssignment
            ? "Переназначить"
            : "Назначить ответственного"}
      </button>
      {snapshot ? <AssignmentForm {...snapshot} /> : null}
    </div>
  );
}
