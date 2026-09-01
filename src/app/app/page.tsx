import type { Metadata } from "next";

import { getAccessibleProjects } from "@/modules/application/server/queries";
import { requireUser } from "@/server/auth/require-user";

import { signOut } from "./actions";
import { ProjectList } from "./projects/project-list";

export const metadata: Metadata = {
  title: "Приложение",
};

export default async function AuthenticatedAppPage() {
  const user = await requireUser();
  const projects = await getAccessibleProjects();

  return (
    <main className="mx-auto min-h-dvh w-full max-w-6xl px-4 py-6 sm:px-8 sm:py-10">
      <header className="mb-8 flex flex-col gap-5 border-b border-slate-200 pb-7 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-bold tracking-[0.16em] text-emerald-700 uppercase">
            Рабочее пространство
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Проекты
          </h1>
          <p className="mt-2 text-sm text-slate-600">
            {user.email ?? "Авторизованный пользователь"}
          </p>
        </div>
        <form action={signOut}>
          <button
            className="min-h-11 rounded-xl border border-slate-300 bg-white px-4 text-sm font-semibold text-slate-800 transition hover:border-slate-500 hover:bg-slate-50"
            type="submit"
          >
            Выйти
          </button>
        </form>
      </header>
      <ProjectList projects={projects} />
    </main>
  );
}
