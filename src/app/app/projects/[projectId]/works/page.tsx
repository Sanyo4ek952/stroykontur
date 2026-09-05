import type { Metadata } from "next";
import Link from "next/link";

import { parseWorkFilters, workStatuses } from "@/modules/works/model/schemas";
import { getWorkCapabilities, getWorks } from "@/modules/works/server/queries";

import { getStatusLabel } from "../../status-labels";
import { Detail, EmptyState, formatDate, PageIntro, StatusBadge } from "../ui";

export const metadata: Metadata = { title: "Работы" };

export default async function ProjectWorksPage({
  params,
  searchParams,
}: PageProps<"/app/projects/[projectId]/works">) {
  const [{ projectId }, rawFilters] = await Promise.all([params, searchParams]);
  const filters = parseWorkFilters(rawFilters);
  const [works, capabilities] = await Promise.all([
    getWorks(projectId, filters),
    getWorkCapabilities(projectId),
  ]);
  const worksPath = `/app/projects/${projectId}/works`;
  const hasFilters = Boolean(filters.search || filters.status);

  return (
    <>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <PageIntro
          description="Плановые параметры, текущие ответственные и состояние производственных работ."
          eyebrow="Производство"
          title="Работы"
        />
        {capabilities.canCreateWork ? (
          <Link
            className="inline-flex min-h-11 items-center rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
            href={`${worksPath}/new`}
          >
            Создать работу
          </Link>
        ) : null}
      </div>

      <form
        action={worksPath}
        className="mb-6 grid gap-3 rounded-2xl border border-slate-200 bg-white p-4 sm:grid-cols-[minmax(0,1fr)_14rem_auto]"
        method="get"
      >
        <div>
          <label
            className="text-sm font-medium text-slate-800"
            htmlFor="work-search"
          >
            Поиск
          </label>
          <input
            className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-base outline-none focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
            defaultValue={filters.search}
            id="work-search"
            name="search"
            placeholder="Код или название"
          />
        </div>
        <div>
          <label
            className="text-sm font-medium text-slate-800"
            htmlFor="work-status"
          >
            Статус
          </label>
          <select
            className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-base outline-none focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
            defaultValue={filters.status ?? ""}
            id="work-status"
            name="status"
          >
            <option value="">Все статусы</option>
            {workStatuses.map((status) => (
              <option key={status} value={status}>
                {getStatusLabel(status)}
              </option>
            ))}
          </select>
        </div>
        <div className="flex items-end gap-2">
          <button
            className="min-h-11 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white hover:bg-slate-800"
            type="submit"
          >
            Применить
          </button>
          {hasFilters ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-xl border border-slate-300 px-4 text-sm font-semibold text-slate-700 hover:bg-slate-50"
              href={worksPath}
            >
              Сбросить
            </Link>
          ) : null}
        </div>
      </form>

      {works.length === 0 ? (
        <EmptyState
          description={
            hasFilters
              ? "Измените поисковый запрос или сбросьте фильтры."
              : undefined
          }
          title={hasFilters ? "Работы не найдены." : "Нет доступных работ."}
        />
      ) : (
        <ul className="space-y-3">
          {works.map((work) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-slate-300 hover:shadow-sm"
              key={work.id}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold tracking-wide text-emerald-700">
                    {work.code}
                  </p>
                  <h2 className="mt-1 text-lg font-semibold text-slate-950">
                    <Link
                      className="hover:text-emerald-800 hover:underline"
                      href={`${worksPath}/${work.id}`}
                    >
                      {work.title}
                    </Link>
                  </h2>
                </div>
                <StatusBadge status={work.status} />
              </div>
              <dl className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                <Detail label="Плановый объём">
                  {work.planned_quantity === null
                    ? "Не задан"
                    : `${work.planned_quantity} ${work.unit}`}
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
