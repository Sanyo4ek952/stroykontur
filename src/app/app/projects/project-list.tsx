import Link from "next/link";

import type { AccessibleProject } from "@/modules/application/server/queries";

import { getStatusLabel } from "./status-labels";

const relationshipLabels: Record<string, string> = {
  contractor: "Подрядчик",
  customer: "Заказчик",
  designer: "Проектировщик",
  general_contractor: "Генподрядчик",
  laboratory: "Лаборатория",
  other: "Участник проекта",
  subcontractor: "Субподрядчик",
  supplier: "Поставщик",
};

export function ProjectList({ projects }: { projects: AccessibleProject[] }) {
  if (projects.length === 0) {
    return (
      <section className="rounded-3xl border border-dashed border-slate-300 bg-white p-8 text-center">
        <h2 className="text-lg font-semibold text-slate-950">
          Нет доступных проектов
        </h2>
        <p className="mt-2 text-sm leading-6 text-slate-600">
          Попросите администратора проекта проверить ваше активное участие.
        </p>
      </section>
    );
  }

  return (
    <ul className="grid gap-4 md:grid-cols-2">
      {projects.map((project) => (
        <li key={project.id}>
          <Link
            className="group flex h-full min-h-48 flex-col rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-lg focus-visible:outline-3 focus-visible:outline-offset-3 focus-visible:outline-emerald-600"
            href={"/app/projects/" + project.id}
          >
            <div className="flex items-start justify-between gap-4">
              <span className="rounded-lg bg-emerald-50 px-2.5 py-1 text-xs font-bold tracking-wide text-emerald-800">
                {project.code}
              </span>
              <span className="text-xs font-medium text-slate-500">
                {getStatusLabel(project.status)}
              </span>
            </div>
            <h2 className="mt-4 text-xl font-semibold tracking-tight text-slate-950 group-hover:text-emerald-800">
              {project.name}
            </h2>
            {project.organizationName ? (
              <p className="mt-auto pt-5 text-sm text-slate-600">
                {project.organizationName}
                {project.organizationRelationship
                  ? " · " +
                    (relationshipLabels[project.organizationRelationship] ??
                      project.organizationRelationship)
                  : ""}
              </p>
            ) : null}
          </Link>
        </li>
      ))}
    </ul>
  );
}
