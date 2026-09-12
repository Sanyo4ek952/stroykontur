import type { Metadata } from "next";
import Link from "next/link";

import { getAccessibleProjects } from "@/modules/application/server/queries";
import { requireUser } from "@/server/auth/require-user";

import { ProjectList } from "./project-list";

export const metadata: Metadata = { title: "Проекты" };

export default async function ProjectsPage() {
  await requireUser();
  const projects = await getAccessibleProjects();

  return (
    <main className="mx-auto min-h-dvh w-full max-w-6xl px-4 py-6 sm:px-8 sm:py-10">
      <Link className="text-sm font-medium text-emerald-800" href="/app">
        ← Рабочее пространство
      </Link>
      <h1 className="mt-5 text-3xl font-semibold tracking-tight text-slate-950">
        Доступные проекты
      </h1>
      <p className="mt-2 mb-7 text-sm leading-6 text-slate-600">
        В списке только проекты, доступные вашей активной учётной записи.
      </p>
      <ProjectList projects={projects} />
    </main>
  );
}
