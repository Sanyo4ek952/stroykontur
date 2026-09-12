import Link from "next/link";
import { z } from "zod";

import { getAccessibleProject } from "@/modules/application/server/queries";
import { requireUser } from "@/server/auth/require-user";

import { signOut } from "../../actions";
import { ProjectNavigation } from "./project-navigation";

const postgresUuidSchema = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

function ProjectUnavailable() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl items-center px-4 py-10">
      <section className="w-full rounded-3xl border border-slate-200 bg-white p-7 text-center shadow-sm">
        <p className="text-sm font-semibold text-slate-500">
          Проект недоступен
        </p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
          Проект не найден
        </h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          Проект не существует или недоступен вашей учётной записи.
        </p>
        <Link
          className="mt-6 inline-flex min-h-11 items-center rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white"
          href="/app"
        >
          К доступным проектам
        </Link>
      </section>
    </main>
  );
}

export default async function ProjectWorkspaceLayout({
  children,
  params,
}: LayoutProps<"/app/projects/[projectId]">) {
  const user = await requireUser();
  const { projectId } = await params;
  const parsedProjectId = postgresUuidSchema.safeParse(projectId);

  if (!parsedProjectId.success) return <ProjectUnavailable />;

  const project = await getAccessibleProject(parsedProjectId.data);
  if (!project) return <ProjectUnavailable />;

  return (
    <main className="min-h-dvh bg-slate-100/70">
      <header className="border-b border-slate-800 bg-slate-950 text-white">
        <div className="mx-auto flex w-full max-w-7xl items-start justify-between gap-5 px-4 py-5 sm:px-8">
          <div className="min-w-0">
            <Link
              className="text-xs font-semibold tracking-wide text-emerald-300 uppercase hover:text-white"
              href="/app"
            >
              ← Все проекты
            </Link>
            <p className="mt-3 text-xs font-bold tracking-wide text-slate-400">
              {project.code}
            </p>
            <p className="mt-1 truncate text-lg font-semibold sm:text-xl">
              {project.name}
            </p>
            {project.organizationName ? (
              <p className="mt-1 truncate text-xs text-slate-400">
                {project.organizationName}
              </p>
            ) : null}
          </div>
          <div className="flex shrink-0 flex-col items-end gap-2">
            <span className="hidden max-w-56 truncate text-xs text-slate-400 sm:block">
              {user.email}
            </span>
            <form action={signOut}>
              <button
                className="min-h-10 rounded-xl border border-slate-700 px-3 text-sm font-semibold text-white transition hover:border-slate-500 hover:bg-slate-900"
                type="submit"
              >
                Выйти
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-7xl px-4 py-4 sm:px-8 lg:grid lg:grid-cols-[14rem_minmax(0,1fr)] lg:gap-8 lg:py-8">
        <aside className="mb-4 rounded-2xl border border-slate-200 bg-white p-2 shadow-sm lg:mb-0 lg:self-start">
          <ProjectNavigation projectId={project.id} />
        </aside>
        <section className="min-w-0 rounded-3xl border border-slate-200 bg-white/70 p-4 shadow-sm sm:p-6 lg:p-8">
          {children}
        </section>
      </div>
    </main>
  );
}
