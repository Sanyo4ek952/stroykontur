"use client";

import Link from "next/link";
import { useActionState } from "react";

import type { DocumentActionState } from "./actions";

type FormAction = (
  state: DocumentActionState,
  formData: FormData,
) => Promise<DocumentActionState>;

const inputClassName =
  "mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-slate-700 focus:ring-3 focus:ring-slate-200";

function FieldError({ errors, id }: { errors?: string[]; id: string }) {
  return errors ? (
    <p className="mt-2 text-sm text-red-700" id={id}>
      {errors.join(" ")}
    </p>
  ) : null;
}

export function DocumentForm({
  action,
  cancelHref,
  kind,
}: {
  action: FormAction;
  cancelHref: string;
  kind: "document" | "revision";
}) {
  const [state, formAction, pending] = useActionState(action, {});
  const isDocument = kind === "document";

  return (
    <form action={formAction} className="max-w-2xl space-y-5" noValidate>
      {isDocument ? (
        <>
          <div>
            <label
              className="block text-sm font-medium text-slate-800"
              htmlFor="code"
            >
              Код документа
            </label>
            <input
              aria-describedby={
                state.fieldErrors?.code ? "code-error" : undefined
              }
              aria-invalid={Boolean(state.fieldErrors?.code)}
              autoComplete="off"
              className={inputClassName}
              id="code"
              name="code"
              required
            />
            <FieldError errors={state.fieldErrors?.code} id="code-error" />
          </div>
          <div>
            <label
              className="block text-sm font-medium text-slate-800"
              htmlFor="title"
            >
              Название
            </label>
            <input
              aria-describedby={
                state.fieldErrors?.title ? "title-error" : undefined
              }
              aria-invalid={Boolean(state.fieldErrors?.title)}
              className={inputClassName}
              id="title"
              name="title"
              required
            />
            <FieldError errors={state.fieldErrors?.title} id="title-error" />
          </div>
        </>
      ) : (
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="revisionCode"
          >
            Код ревизии
          </label>
          <input
            aria-describedby={
              state.fieldErrors?.revisionCode
                ? "revision-code-error"
                : undefined
            }
            aria-invalid={Boolean(state.fieldErrors?.revisionCode)}
            autoComplete="off"
            className={inputClassName}
            id="revisionCode"
            name="revisionCode"
            required
          />
          <FieldError
            errors={state.fieldErrors?.revisionCode}
            id="revision-code-error"
          />
          <p className="mt-2 text-sm text-slate-600">
            Новая ревизия будет создана в статусе «Черновик».
          </p>
        </div>
      )}

      {state.message ? (
        <p
          className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
          role="alert"
        >
          {state.message}
        </p>
      ) : null}

      <div className="flex flex-wrap gap-3">
        <button
          className="min-h-11 rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-wait disabled:bg-slate-500"
          disabled={pending}
          type="submit"
        >
          {pending
            ? "Сохраняем…"
            : isDocument
              ? "Создать документ"
              : "Создать ревизию"}
        </button>
        <Link
          className="inline-flex min-h-11 items-center rounded-xl border border-slate-300 px-5 text-sm font-semibold text-slate-700 hover:bg-slate-50"
          href={cancelHref}
        >
          Отмена
        </Link>
      </div>
    </form>
  );
}
