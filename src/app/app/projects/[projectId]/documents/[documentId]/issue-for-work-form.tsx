"use client";

import { useActionState } from "react";

import {
  issueDocumentRevisionForWork,
  type DocumentActionState,
} from "../actions";

const initialState: DocumentActionState = {};

export function IssueForWorkForm({
  currentRevisionCode,
  documentId,
  projectId,
  revisionCode,
  revisionId,
}: {
  currentRevisionCode: string | null;
  documentId: string;
  projectId: string;
  revisionCode: string;
  revisionId: string;
}) {
  const action = issueDocumentRevisionForWork.bind(
    null,
    projectId,
    documentId,
    revisionId,
  );
  const [state, formAction, pending] = useActionState(action, initialState);
  const confirmation = currentRevisionCode
    ? `Выдать ревизию ${revisionCode} в производство? Текущая производственная ревизия ${currentRevisionCode} будет заменена, а её история сохранится.`
    : `Выдать ревизию ${revisionCode} в производство? Для связанных работ будут созданы влияния и задачи.`;

  return (
    <form
      action={formAction}
      className="mt-3"
      onSubmit={(event) => {
        if (!window.confirm(confirmation)) event.preventDefault();
      }}
    >
      <button
        className="min-h-10 rounded-lg bg-emerald-700 px-4 text-sm font-semibold text-white hover:bg-emerald-800 disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending ? "Выдача…" : "Выдать в производство"}
      </button>
      {state.message ? (
        <p
          aria-live="polite"
          className={`mt-2 text-sm ${state.success ? "text-emerald-700" : "text-red-700"}`}
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
