import type { Metadata } from "next";
import Link from "next/link";

import { SignInForm } from "./sign-in-form";

export const metadata: Metadata = {
  title: "Вход",
};

export default function LoginPage() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md items-center px-5 py-10 sm:px-8">
      <section
        aria-labelledby="login-title"
        className="w-full rounded-3xl border border-slate-200 bg-white p-6 shadow-xl shadow-slate-200/50 sm:p-8"
      >
        <p className="text-sm font-semibold tracking-[0.14em] text-slate-600 uppercase">
          Строительный объект
        </p>
        <h1
          className="mt-3 text-3xl font-semibold tracking-tight text-slate-950"
          id="login-title"
        >
          Вход в систему
        </h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          Используйте выданные вам учётные данные.
        </p>

        <SignInForm />

        <Link
          className="mt-6 inline-flex min-h-11 items-center text-sm font-medium text-slate-700 underline decoration-slate-300 underline-offset-4 hover:text-slate-950"
          href="/"
        >
          Вернуться на главную
        </Link>
      </section>
    </main>
  );
}
