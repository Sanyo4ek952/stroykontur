"use client";

import { useActionState } from "react";

import { signIn, type SignInState } from "./actions";

const initialSignInState: SignInState = {};

export function SignInForm() {
  const [state, formAction, pending] = useActionState(
    signIn,
    initialSignInState,
  );
  const emailErrorId = state.fieldErrors?.email ? "email-error" : undefined;
  const passwordErrorId = state.fieldErrors?.password
    ? "password-error"
    : undefined;

  return (
    <form action={formAction} className="mt-8 space-y-5" noValidate>
      <div>
        <label
          className="block text-sm font-medium text-slate-800"
          htmlFor="email"
        >
          Электронная почта
        </label>
        <input
          aria-describedby={emailErrorId}
          aria-invalid={Boolean(emailErrorId)}
          autoComplete="email"
          className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
          id="email"
          name="email"
          required
          type="email"
        />
        {state.fieldErrors?.email ? (
          <p className="mt-2 text-sm text-red-700" id={emailErrorId}>
            {state.fieldErrors.email.join(" ")}
          </p>
        ) : null}
      </div>

      <div>
        <label
          className="block text-sm font-medium text-slate-800"
          htmlFor="password"
        >
          Пароль
        </label>
        <input
          aria-describedby={passwordErrorId}
          aria-invalid={Boolean(passwordErrorId)}
          autoComplete="current-password"
          className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
          id="password"
          name="password"
          required
          type="password"
        />
        {state.fieldErrors?.password ? (
          <p className="mt-2 text-sm text-red-700" id={passwordErrorId}>
            {state.fieldErrors.password.join(" ")}
          </p>
        ) : null}
      </div>

      {state.message ? (
        <p
          className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
          role="alert"
        >
          {state.message}
        </p>
      ) : null}

      <button
        className="min-h-12 w-full rounded-xl bg-slate-950 px-5 text-base font-semibold text-white transition hover:bg-slate-800 disabled:cursor-wait disabled:bg-slate-500"
        disabled={pending}
        type="submit"
      >
        {pending ? "Входим…" : "Войти"}
      </button>
    </form>
  );
}
