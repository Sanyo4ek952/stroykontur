"use client";

import Link from "next/link";
import { useActionState, useState } from "react";

import {
  linkDocumentWork,
  type DocumentWorkLinkActionState,
  unlinkDocumentWork,
} from "./document-work-link-actions";

type Candidate = {
  code: string;
  hasActiveIssue: boolean;
  id: string;
  title: string;
};

type LinkItem = {
  code: string;
  id: string;
  removedAt: string | null;
  removalReason: string | null;
  secondary?: string | null;
  title: string;
  url: string;
};

const initialState: DocumentWorkLinkActionState = {};

function SubmitMessage({ state }: { state: DocumentWorkLinkActionState }) {
  return state.message ? (
    <p
      aria-live="polite"
      className={`mt-2 text-sm ${state.success ? "text-emerald-700" : "text-red-700"}`}
    >
      {state.message}
    </p>
  ) : null;
}

function LinkForm({
  candidates,
  fixedId,
  mode,
  projectId,
}: {
  candidates: Candidate[];
  fixedId: string;
  mode: "document" | "work";
  projectId: string;
}) {
  const action = linkDocumentWork.bind(null, projectId);
  const [state, formAction, pending] = useActionState(action, initialState);
  const [selectedId, setSelectedId] = useState(candidates[0]?.id ?? "");
  const selected = candidates.find(({ id }) => id === selectedId);

  if (candidates.length === 0) {
    return (
      <p className="mt-3 text-sm text-slate-600">
        Доступных вариантов не найдено.
      </p>
    );
  }

  return (
    <form
      action={formAction}
      className="mt-4 rounded-xl border border-slate-200 p-4"
    >
      <input
        name={mode === "document" ? "documentId" : "workId"}
        type="hidden"
        value={fixedId}
      />
      <label
        className="block text-sm font-semibold text-slate-800"
        htmlFor={`link-${mode}`}
      >
        {mode === "document" ? "Работа" : "Документ"}
      </label>
      <select
        className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3"
        id={`link-${mode}`}
        name={mode === "document" ? "workId" : "documentId"}
        onChange={(event) => setSelectedId(event.target.value)}
        value={selectedId}
      >
        {candidates.map((candidate) => (
          <option key={candidate.id} value={candidate.id}>
            {candidate.code} — {candidate.title}
          </option>
        ))}
      </select>

      {selected?.hasActiveIssue ? (
        <div className="mt-3 rounded-xl border border-amber-300 bg-amber-50 p-3 text-sm text-amber-950">
          <p className="font-semibold">
            У документа уже есть действующая выдача в производство.
          </p>
          <p className="mt-1">
            После создания связи система сразу зафиксирует влияние на эту работу
            и создаст задачу ответственному, если он назначен.
          </p>
          <label className="mt-3 flex items-start gap-2 font-medium">
            <input
              className="mt-1"
              name="confirmedActiveIssue"
              required
              type="checkbox"
            />
            Подтверждаю немедленный запуск цепочки влияния.
          </label>
        </div>
      ) : null}

      <button
        className="mt-4 min-h-11 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending
          ? "Сохранение…"
          : mode === "document"
            ? "Связать работу"
            : "Связать документ"}
      </button>
      <SubmitMessage state={state} />
    </form>
  );
}

function UnlinkForm({
  linkId,
  projectId,
}: {
  linkId: string;
  projectId: string;
}) {
  const action = unlinkDocumentWork.bind(null, projectId);
  const [state, formAction, pending] = useActionState(action, initialState);

  return (
    <form action={formAction} className="mt-3 border-t border-slate-100 pt-3">
      <input name="linkId" type="hidden" value={linkId} />
      <p className="text-sm text-amber-900">
        Связь будет закрыта для будущих выдач. Уже созданные влияния, задачи и
        уведомления останутся в истории.
      </p>
      <label className="mt-2 flex items-start gap-2 text-sm text-slate-700">
        <input
          className="mt-1"
          name="confirmedUnlink"
          required
          type="checkbox"
        />
        Подтверждаю историческое закрытие связи.
      </label>
      <label
        className="mt-2 block text-sm text-slate-700"
        htmlFor={`reason-${linkId}`}
      >
        Причина (необязательно)
      </label>
      <input
        className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 px-3"
        id={`reason-${linkId}`}
        maxLength={500}
        name="reason"
      />
      <button
        className="mt-3 min-h-10 rounded-lg border border-red-300 px-3 text-sm font-semibold text-red-800 disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        {pending ? "Закрытие…" : "Убрать связь"}
      </button>
      <SubmitMessage state={state} />
    </form>
  );
}

export function DocumentWorkLinkManager({
  canManage,
  candidates,
  fixedId,
  items,
  mode,
  projectId,
  search,
}: {
  canManage: boolean;
  candidates: Candidate[];
  fixedId: string;
  items: LinkItem[];
  mode: "document" | "work";
  projectId: string;
  search: string;
}) {
  const active = items.filter(({ removedAt }) => !removedAt);
  const history = items.filter(({ removedAt }) => removedAt);
  const searchName = mode === "document" ? "workSearch" : "documentSearch";

  return (
    <section className="mt-6">
      <h2 className="text-xl font-semibold text-slate-950">
        {mode === "document" ? "Связанные работы" : "Связанные документы"}
      </h2>
      {active.length === 0 ? (
        <p className="mt-3 text-sm text-slate-600">Активных связей нет.</p>
      ) : (
        <ul className="mt-3 space-y-3">
          {active.map((item) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-4"
              key={item.id}
            >
              <p className="text-xs font-bold text-emerald-700">{item.code}</p>
              <Link
                className="mt-1 block font-semibold text-slate-950 hover:underline"
                href={item.url}
              >
                {item.title}
              </Link>
              {item.secondary ? (
                <p className="mt-1 text-sm text-slate-600">{item.secondary}</p>
              ) : null}
              {canManage ? (
                <UnlinkForm linkId={item.id} projectId={projectId} />
              ) : null}
            </li>
          ))}
        </ul>
      )}

      {canManage ? (
        <div className="mt-5 rounded-2xl border border-slate-200 bg-white p-5">
          <h3 className="font-semibold text-slate-950">
            {mode === "document" ? "Связать работу" : "Связать документ"}
          </h3>
          <form className="mt-3 flex flex-wrap gap-2" method="get">
            <label className="sr-only" htmlFor={`search-${mode}`}>
              Поиск кандидатов
            </label>
            <input
              className="min-h-11 flex-1 rounded-xl border border-slate-300 px-3"
              defaultValue={search}
              id={`search-${mode}`}
              name={searchName}
              placeholder="Поиск по коду или названию"
            />
            <button
              className="min-h-11 rounded-xl border border-slate-300 px-4 font-semibold"
              type="submit"
            >
              Найти
            </button>
          </form>
          <LinkForm
            candidates={candidates}
            fixedId={fixedId}
            mode={mode}
            projectId={projectId}
          />
        </div>
      ) : null}

      {history.length > 0 ? (
        <div className="mt-5">
          <h3 className="font-semibold text-slate-950">История связей</h3>
          <ul className="mt-2 space-y-2">
            {history.map((item) => (
              <li
                className="rounded-xl border border-slate-200 bg-slate-50 p-3 text-sm"
                key={item.id}
              >
                <Link className="font-semibold hover:underline" href={item.url}>
                  {item.code} — {item.title}
                </Link>
                <p className="mt-1 text-slate-600">
                  Закрыта{" "}
                  {new Intl.DateTimeFormat("ru-RU", {
                    dateStyle: "medium",
                    timeStyle: "short",
                  }).format(new Date(item.removedAt!))}
                  {item.removalReason ? ` · ${item.removalReason}` : ""}
                </p>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
