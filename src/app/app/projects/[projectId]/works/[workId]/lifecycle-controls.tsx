"use client";

import { useActionState } from "react";

import {
  acceptWork,
  blockWork,
  closeWork,
  markWorkReady,
  markWorkReadyForInspection,
  requireWorkRework,
  resumeBlockedWork,
  startWork,
  type WorkLifecycleActionState,
} from "../actions";

import type { WorkLifecycleActionName } from "@/modules/works/model/lifecycle";

const actions: Record<
  WorkLifecycleActionName,
  {
    action: (
      projectId: string,
      workId: string,
      state: WorkLifecycleActionState,
    ) => Promise<WorkLifecycleActionState>;
    confirm?: string;
    label: string;
  }
> = {
  accept: { action: acceptWork, label: "Принять работу" },
  block: { action: blockWork, label: "Заблокировать работу" },
  close: {
    action: closeWork,
    confirm:
      "Закрытую работу нельзя вернуть в предыдущий статус. Закрыть работу?",
    label: "Закрыть работу",
  },
  ready: { action: markWorkReady, label: "Подготовить к работе" },
  readyForInspection: {
    action: markWorkReadyForInspection,
    label: "Передать на проверку",
  },
  resume: { action: resumeBlockedWork, label: "Возобновить работу" },
  rework: {
    action: requireWorkRework,
    confirm: "Работа будет возвращена на доработку. Продолжить?",
    label: "Вернуть на доработку",
  },
  start: { action: startWork, label: "Начать работу" },
};

function LifecycleButton({
  actionName,
  projectId,
  workId,
}: {
  actionName: WorkLifecycleActionName;
  projectId: string;
  workId: string;
}) {
  const config = actions[actionName];
  const [state, formAction, pending] = useActionState(
    config.action.bind(null, projectId, workId),
    {},
  );

  return (
    <form
      action={formAction}
      onSubmit={(event) => {
        if (config.confirm && !window.confirm(config.confirm)) {
          event.preventDefault();
        }
      }}
    >
      <button
        className="rounded-xl bg-emerald-700 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-800 disabled:cursor-wait disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending ? "Выполняется…" : config.label}
      </button>
      {state.message ? (
        <p
          className="mt-2 max-w-sm text-sm font-medium text-red-700"
          role="alert"
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}

export function WorkLifecycleControls({
  availableActions,
  projectId,
  workId,
}: {
  availableActions: WorkLifecycleActionName[];
  projectId: string;
  workId: string;
}) {
  if (availableActions.length === 0) return null;
  return (
    <section className="mt-6 rounded-2xl border border-emerald-200 bg-emerald-50 p-5">
      <h2 className="text-lg font-semibold text-slate-950">
        Действия с работой
      </h2>
      <div className="mt-4 flex flex-wrap gap-3">
        {availableActions.map((actionName) => (
          <LifecycleButton
            actionName={actionName}
            key={actionName}
            projectId={projectId}
            workId={workId}
          />
        ))}
      </div>
    </section>
  );
}
