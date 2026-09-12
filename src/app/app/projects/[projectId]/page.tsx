import Link from "next/link";

import { getProjectOverview } from "@/modules/application/server/queries";

import { PageIntro } from "./ui";

export default async function ProjectOverviewPage({
  params,
}: PageProps<"/app/projects/[projectId]">) {
  const { projectId } = await params;
  const overview = await getProjectOverview(projectId);
  const metrics = [
    {
      href: "tasks",
      label: "Мои открытые задачи",
      value: overview.openTaskCount,
    },
    {
      href: "notifications",
      label: "Непрочитанные уведомления",
      value: overview.unreadNotificationCount,
    },
    {
      href: "documents",
      label: "Технические документы",
      value: overview.documentCount,
    },
    { href: "works", label: "Работы проекта", value: overview.workCount },
  ];

  return (
    <>
      <PageIntro
        description="Короткая сводка по данным, доступным вам в текущем проекте."
        eyebrow="Обзор"
        title="Что требует внимания"
      />
      <div className="grid gap-3 sm:grid-cols-2">
        {metrics.map((metric) => (
          <Link
            className="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-emerald-300 hover:shadow-md"
            href={metric.href}
            key={metric.href}
          >
            <p className="text-3xl font-semibold tracking-tight text-slate-950">
              {metric.value}
            </p>
            <p className="mt-2 text-sm font-medium text-slate-600">
              {metric.label}
            </p>
          </Link>
        ))}
      </div>
      <section className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 p-5">
        <p className="text-2xl font-semibold text-amber-950">
          {overview.impactCount}
        </p>
        <p className="mt-1 text-sm font-medium text-amber-900">
          Изменения документации требуют внимания
        </p>
      </section>
    </>
  );
}
