import type { Metadata } from "next";

import { getProjectDocuments } from "@/modules/application/server/queries";

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
}: PageProps<"/app/projects/[projectId]/documents">) {
  const { projectId } = await params;
  const documents = await getProjectDocuments(projectId);

  return (
    <>
      <PageIntro
        description="Технические документы, их последние ревизии и текущее состояние выдачи в производство."
        eyebrow="Документация"
        title="Документы"
      />
      {documents.length === 0 ? (
        <EmptyState title="Нет доступных документов." />
      ) : (
        <ul className="space-y-3">
          {documents.map((document) => (
            <li
              className="rounded-2xl border border-slate-200 bg-white p-5"
              key={document.id}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold tracking-wide text-emerald-700">
                    {document.code}
                  </p>
                  <h2 className="mt-1 text-lg font-semibold text-slate-950">
                    {document.title}
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
