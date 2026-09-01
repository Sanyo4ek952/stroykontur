import type { Metadata } from "next";

import {
  getAccessibleProject,
  getProjectWorks,
} from "@/modules/application/server/queries";

import { Detail, EmptyState, formatDate, PageIntro, StatusBadge } from "../ui";

export const metadata: Metadata = { title: "Работы" };

export default async function ProjectWorksPage({
  params,
}: PageProps<"/app/projects/[projectId]/works">) {
  const { projectId } = await params;
  const project = await getAccessibleProject(projectId);
  const works = await getProjectWorks(
    projectId,
    project?.ownProjectMemberId ?? null,
  );

  return (
    <>
      <PageIntro
        description="Плановые параметры и текущее состояние производственных работ."
        eyebrow="Производство"
        title="Работы"
      />
      {works.length === 0 ? (
        <EmptyState title="В проекте пока нет работ." />
      ) : (
        <ul className="space-y-3">
          {works.map((work) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-5"
              key={work.id}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold tracking-wide text-emerald-700">
                    {work.code}
                  </p>
                  <h2 className="mt-1 text-lg font-semibold text-slate-950">
                    {work.title}
                  </h2>
                </div>
                <StatusBadge status={work.status} />
              </div>
              <dl className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                <Detail label="Плановый объём">
                  {work.planned_quantity === null
                    ? "Не задан"
                    : work.planned_quantity + " " + work.unit}
                </Detail>
                <Detail label="Плановый старт">
                  {formatDate(work.planned_start_date)}
                </Detail>
                <Detail label="Плановый финиш">
                  {formatDate(work.planned_finish_date)}
                </Detail>
                <Detail label="Ответственный">
                  {work.responsibleLabel ?? "Не назначен"}
                </Detail>
              </dl>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
