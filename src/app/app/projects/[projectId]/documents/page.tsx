import type { Metadata } from "next";
import Link from "next/link";

import {
  documentRevisionStatuses,
  parseDocumentFilters,
} from "@/modules/documents/model/schemas";
import {
  getDocumentCapabilities,
  getDocuments,
} from "@/modules/documents/server/queries";

import { getStatusLabel } from "../../status-labels";
import {
  Detail,
  EmptyState,
  formatDateTime,
  PageIntro,
  StatusBadge,
} from "../ui";

export const metadata: Metadata = { title: "Документы" };

export default async function ProjectDocumentsPage({
  params,
  searchParams,
}: PageProps<"/app/projects/[projectId]/documents">) {
  const [{ projectId }, rawFilters] = await Promise.all([params, searchParams]);
  const filters = parseDocumentFilters(rawFilters);
  const [documents, capabilities] = await Promise.all([
    getDocuments(projectId, filters),
    getDocumentCapabilities(projectId),
  ]);
  const documentsPath = `/app/projects/${projectId}/documents`;
  const hasFilters = Boolean(filters.search || filters.status);

  return (
    <>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <PageIntro
          description="Технические документы, история ревизий и состояние выдачи в производство."
          eyebrow="Документация"
          title="Документы"
        />
        {capabilities.canCreateDocument ? (
          <Link
            className="inline-flex min-h-11 items-center rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
            href={`${documentsPath}/new`}
          >
            Создать документ
          </Link>
        ) : null}
      </div>

      <form
        action={documentsPath}
        className="mb-6 grid gap-3 rounded-2xl border border-slate-200 bg-white p-4 sm:grid-cols-[minmax(0,1fr)_14rem_auto]"
        method="get"
      >
        <div>
          <label
            className="text-sm font-medium text-slate-800"
            htmlFor="document-search"
          >
            Поиск
          </label>
          <input
            className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-base outline-none focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
            defaultValue={filters.search}
            id="document-search"
            name="search"
            placeholder="Код или название"
          />
        </div>
        <div>
          <label
            className="text-sm font-medium text-slate-800"
            htmlFor="document-status"
          >
            Статус ревизии
          </label>
          <select
            className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-base outline-none focus:border-slate-700 focus:ring-3 focus:ring-slate-200"
            defaultValue={filters.status ?? ""}
            id="document-status"
            name="status"
          >
            <option value="">Все статусы</option>
            {documentRevisionStatuses.map((status) => (
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
              href={documentsPath}
            >
              Сбросить
            </Link>
          ) : null}
        </div>
      </form>

      {documents.length === 0 ? (
        <EmptyState
          description={
            hasFilters
              ? "Измените поисковый запрос или сбросьте фильтры."
              : undefined
          }
          title={
            hasFilters ? "Документы не найдены." : "Нет доступных документов."
          }
        />
      ) : (
        <ul className="space-y-3">
          {documents.map((document) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-slate-300 hover:shadow-sm"
              key={document.id}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold tracking-wide text-emerald-700">
                    {document.code}
                  </p>
                  <h2 className="mt-1 text-lg font-semibold text-slate-950">
                    <Link
                      className="hover:text-emerald-800 hover:underline"
                      href={`${documentsPath}/${document.id}`}
                    >
                      {document.title}
                    </Link>
                  </h2>
                </div>
                {document.latestRevision ? (
                  <StatusBadge status={document.latestRevision.status} />
                ) : null}
              </div>
              <dl className="mt-5 grid gap-4 sm:grid-cols-3">
                <Detail label="Последняя ревизия">
                  {document.latestRevision?.revision_code ?? "Нет ревизий"}
                </Detail>
                <Detail label="Выдача в производство">
                  {document.currentIssue ? "Действует" : "Не выдан"}
                </Detail>
                <Detail label="Обновлено">
                  {formatDateTime(document.updated_at)}
                </Detail>
              </dl>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
