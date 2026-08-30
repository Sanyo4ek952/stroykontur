import type { Metadata } from "next";

import { requireUser } from "@/server/auth/require-user";

import { signOut } from "./actions";

export const metadata: Metadata = {
  title: "Приложение",
};

export default async function AuthenticatedAppPage() {
  const user = await requireUser();

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-3xl items-center px-5 py-10 sm:px-8">
      <section
        aria-labelledby="app-title"
        className="w-full rounded-3xl border border-slate-200 bg-white p-6 shadow-xl shadow-slate-200/50 sm:p-8"
      >
        <p className="text-sm font-semibold tracking-[0.14em] text-emerald-700 uppercase">
          Аутентификация подтверждена
        </p>
        <h1
          className="mt-3 text-3xl font-semibold tracking-tight text-slate-950"
          id="app-title"
        >
          Защищённая область
        </h1>
        <p className="mt-4 text-base leading-7 text-slate-600">
          Вы вошли как{" "}
          <span className="font-medium text-slate-900">
            {user.email ?? user.id}
          </span>
          .
        </p>
        <p className="mt-2 text-sm leading-6 text-slate-500">
          Проекты, роли и рабочие модули будут добавлены отдельными задачами.
        </p>

        <form action={signOut} className="mt-8">
          <button
            className="min-h-12 rounded-xl border border-slate-300 bg-white px-5 text-base font-semibold text-slate-800 transition hover:border-slate-500 hover:bg-slate-50"
            type="submit"
          >
            Выйти
          </button>
        </form>
      </section>
    </main>
  );
}
