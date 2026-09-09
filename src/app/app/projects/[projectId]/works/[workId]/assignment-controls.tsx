"use client";

import { useActionState, useState } from "react";
import { assignWork, reassignWork } from "../assignment-actions";

type Props = {
  projectId: string;
  workId: string;
  currentAssignment: { id: string; responsibleLabel: string } | null;
  candidates: { id: string; label: string }[];
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
    <form action={action} className="mt-4 space-y-3">
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
          <p>Текущий ответственный: {currentAssignment.responsibleLabel}</p>
        </>
      ) : null}
      <label className="block text-sm font-medium">
        Новый ответственный
        <select
          name="newProjectMemberId"
          required
          disabled={pending || state.success}
          defaultValue=""
          className="mt-1 block w-full rounded-lg border border-slate-300 p-2"
        >
          <option value="" disabled>
            Выберите участника
          </option>
          {candidates.map((member) => (
            <option key={member.id} value={member.id}>
              {member.label}
            </option>
          ))}
        </select>
      </label>
      <label className="block text-sm font-medium">
        {currentAssignment
          ? "Причина переназначения"
          : "Причина назначения (необязательно)"}
        <textarea
          name="reason"
          required={Boolean(currentAssignment)}
          maxLength={2000}
          disabled={pending || state.success}
          className="mt-1 block w-full rounded-lg border border-slate-300 p-2"
        />
      </label>
      <button
        disabled={pending || state.success || candidates.length === 0}
        className="rounded-lg bg-emerald-800 px-4 py-2 font-semibold text-white disabled:opacity-50"
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
    <div className="mt-4">
      <button
        type="button"
        className="font-semibold text-emerald-800 hover:underline"
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
