"use client";

import Link from "next/link";
import { useActionState } from "react";

import type { WorkActionState } from "./actions";

type FormAction = (
  state: WorkActionState,
  formData: FormData,
) => Promise<WorkActionState>;

const inputClassName =
  "mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-slate-700 focus:ring-3 focus:ring-slate-200";

function FieldError({ errors, id }: { errors?: string[]; id: string }) {
  return errors ? (
    <p className="mt-2 text-sm text-red-700" id={id}>
      {errors.join(" ")}
    </p>
  ) : null;
}

export function WorkForm({
  action,
  cancelHref,
}: {
  action: FormAction;
  cancelHref: string;
}) {
  const [state, formAction, pending] = useActionState(action, {});

  return (
    <form action={formAction} className="max-w-3xl space-y-5" noValidate>
      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="code"
          >
            Код работы
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
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="plannedQuantity"
          >
            Плановый объём
          </label>
          <input
            aria-describedby={
              state.fieldErrors?.plannedQuantity ? "quantity-error" : undefined
            }
            aria-invalid={Boolean(state.fieldErrors?.plannedQuantity)}
            className={inputClassName}
            id="plannedQuantity"
            inputMode="decimal"
            min="0"
            name="plannedQuantity"
            step="any"
            type="number"
          />
          <FieldError
            errors={state.fieldErrors?.plannedQuantity}
            id="quantity-error"
          />
        </div>
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="unit"
          >
            Единица измерения
          </label>
          <input
            aria-describedby={
              state.fieldErrors?.unit ? "unit-error" : undefined
            }
            aria-invalid={Boolean(state.fieldErrors?.unit)}
            autoComplete="off"
            className={inputClassName}
            id="unit"
            name="unit"
            placeholder="м³, т, шт."
          />
          <FieldError errors={state.fieldErrors?.unit} id="unit-error" />
        </div>
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="plannedStartDate"
          >
            Плановый старт
          </label>
          <input
            aria-describedby={
              state.fieldErrors?.plannedStartDate
                ? "start-date-error"
                : undefined
            }
            aria-invalid={Boolean(state.fieldErrors?.plannedStartDate)}
            className={inputClassName}
            id="plannedStartDate"
            name="plannedStartDate"
            type="date"
          />
          <FieldError
            errors={state.fieldErrors?.plannedStartDate}
            id="start-date-error"
          />
        </div>
        <div>
          <label
            className="block text-sm font-medium text-slate-800"
            htmlFor="plannedFinishDate"
          >
            Плановый финиш
          </label>
          <input
            aria-describedby={
              state.fieldErrors?.plannedFinishDate
                ? "finish-date-error"
                : undefined
            }
            aria-invalid={Boolean(state.fieldErrors?.plannedFinishDate)}
            className={inputClassName}
            id="plannedFinishDate"
            name="plannedFinishDate"
            type="date"
          />
          <FieldError
            errors={state.fieldErrors?.plannedFinishDate}
            id="finish-date-error"
          />
        </div>
      </div>

      <p className="text-sm text-slate-600">
        Новая работа будет создана в начальном статусе «Запланирована».
      </p>
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
          {pending ? "Сохраняем…" : "Создать работу"}
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
