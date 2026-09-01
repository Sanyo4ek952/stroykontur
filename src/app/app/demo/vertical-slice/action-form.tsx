"use client";

import { useActionState } from "react";

import type { DemoActionState } from "./actions";

type DemoAction = (
  state: DemoActionState,
  formData: FormData,
) => Promise<DemoActionState>;

export function ActionForm({
  action,
  label,
  notificationId,
  pendingLabel,
}: {
  action: DemoAction;
  label: string;
  notificationId: string;
  pendingLabel: string;
}) {
  const [state, formAction, pending] = useActionState(action, {});

  return (
    <form action={formAction} className="mt-4">
      <input name="notificationId" type="hidden" value={notificationId} />
      <button
        className="min-h-11 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-wait disabled:bg-slate-500"
        disabled={pending}
        type="submit"
      >
        {pending ? pendingLabel : label}
      </button>
      {state.message ? (
        <p
          className={`mt-3 text-sm ${
            state.status === "error" ? "text-red-700" : "text-emerald-700"
          }`}
          role="status"
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
