import type { Metadata } from "next";
import Link from "next/link";

import { postgresUuidSchema } from "@/modules/documents/model/schemas";

import {
  getDocumentCapabilities,
  getDocumentDetails,
} from "@/modules/documents/server/queries";
import { getDocumentWorkLinkData } from "@/modules/document-work-links/server/queries";

import { DocumentWorkLinkManager } from "../../document-work-link-manager";
import {
  Detail,
  EmptyState,
  formatDateTime,
  PageIntro,
  StatusBadge,
} from "../../ui";
import { IssueForWorkForm } from "./issue-for-work-form";

export const metadata: Metadata = { title: "Карточка документа" };

export default async function TechnicalDocumentDetailsPage({
  params,
  searchParams,
}: {
  params: Promise<{ documentId: string; projectId: string }>;
  searchParams: Promise<{ workSearch?: string }>;
}) {
  const { documentId, projectId } = await params;
  const { workSearch = "" } = await searchParams;
  const parsedDocumentId = postgresUuidSchema.safeParse(documentId);
  if (!parsedDocumentId.success) {
    return <EmptyState title="Документ не найден." />;
  }

  const [document, capabilities, linkData] = await Promise.all([
    getDocumentDetails(projectId, parsedDocumentId.data),
    getDocumentCapabilities(projectId),
    getDocumentWorkLinkData(
      projectId,
      parsedDocumentId.data,
      workSearch.trim(),
    ),
  ]);
  if (!document) return <EmptyState title="Документ не найден." />;

  const documentPath = `/app/projects/${projectId}/documents/${document.id}`;
  const currentIssue = document.issues.find(
    ({ withdrawn_at }) => !withdrawn_at,
  );

  return (
    <>
      <Link
        className="mb-4 inline-flex text-sm font-semibold text-emerald-800 hover:underline"
        href={`/app/projects/${projectId}/documents`}
      >
        ← К документам
      </Link>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <PageIntro
          description="Карточка документа, ревизии и история выдачи в производство."
          eyebrow={document.code}
          title={document.title}
        />
        {capabilities.canCreateRevision ? (
          <Link
            className="inline-flex min-h-11 items-center rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white hover:bg-slate-800"
            href={`${documentPath}/revisions/new`}
          >
            Создать ревизию
          </Link>
        ) : null}
      </div>

      <section className="rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-lg font-semibold text-slate-950">Документ</h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-3">
          <Detail label="Код">{document.code}</Detail>
          <Detail label="Создан">{formatDateTime(document.created_at)}</Detail>
          <Detail label="Обновлён">
            {formatDateTime(document.updated_at)}
          </Detail>
        </dl>
      </section>

      <section className="mt-6 rounded-2xl border border-emerald-200 bg-emerald-50 p-5">
        <h2 className="text-lg font-semibold text-slate-950">
          Текущая производственная ревизия
        </h2>
        <p className="mt-2 text-sm text-slate-700">
          {currentIssue
            ? `Ревизия ${currentIssue.revisionCode}, выдана ${formatDateTime(currentIssue.issued_at)}.`
            : "Документ ещё не выдавался в производство."}
        </p>
      </section>

      <DocumentWorkLinkManager
        canManage={linkData.canManage}
        candidates={linkData.candidates}
        fixedId={document.id}
        items={linkData.links.map((link) => ({
          code: link.work.code,
          id: link.id,
          removedAt: link.removed_at,
          removalReason: link.removal_reason,
          secondary: `Статус: ${link.work.status}${link.work.responsibleLabel ? ` · Ответственный: ${link.work.responsibleLabel}` : ""}`,
          title: link.work.title,
          url: `/app/projects/${projectId}/works/${link.work.id}`,
        }))}
        mode="document"
        projectId={projectId}
        search={workSearch}
      />

      <section className="mt-6">
        <h2 className="text-xl font-semibold text-slate-950">
          История ревизий
        </h2>
        {document.revisions.length === 0 ? (
          <div className="mt-3">
            <EmptyState title="У документа пока нет ревизий." />
          </div>
        ) : (
          <ol className="mt-3 space-y-3">
            {document.revisions.map((revision) => (
              <li
                className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4"
                key={revision.id}
              >
                <div>
                  <p className="font-semibold text-slate-950">
                    Ревизия {revision.revision_code}
                  </p>
                  <p className="mt-1 text-sm text-slate-600">
                    Создана {formatDateTime(revision.created_at)}
                  </p>
                </div>
                <StatusBadge status={revision.status} />
                {revision.status === "approved" &&
                capabilities.canIssueForWork &&
                currentIssue?.document_revision_id !== revision.id ? (
                  <IssueForWorkForm
                    currentRevisionCode={currentIssue?.revisionCode ?? null}
                    documentId={document.id}
                    projectId={projectId}
                    revisionCode={revision.revision_code}
                    revisionId={revision.id}
                  />
                ) : null}
              </li>
            ))}
          </ol>
        )}
      </section>

      <section className="mt-6">
        <h2 className="text-xl font-semibold text-slate-950">
          История выдачи в производство
        </h2>
        <p className="mt-1 text-sm text-slate-600">Только просмотр.</p>
        {document.issues.length === 0 ? (
          <div className="mt-3">
            <EmptyState title="Документ ещё не выдавался в производство." />
          </div>
        ) : (
          <ol className="mt-3 space-y-3">
            {document.issues.map((issue) => (
              <li
                className="rounded-2xl border border-slate-200 bg-white p-4"
                key={issue.id}
              >
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="font-semibold text-slate-950">
                    Ревизия {issue.revisionCode}
                  </p>
                  <span
                    className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${
                      issue.withdrawn_at
                        ? "bg-slate-100 text-slate-700"
                        : "bg-emerald-100 text-emerald-800"
                    }`}
                  >
                    {issue.withdrawn_at ? "Отозвана" : "Действует"}
                  </span>
                </div>
                <dl className="mt-4 grid gap-4 sm:grid-cols-2">
                  <Detail label="Выдана">
                    {formatDateTime(issue.issued_at)}
                  </Detail>
                  <Detail label="Отозвана">
                    {formatDateTime(issue.withdrawn_at)}
                  </Detail>
                </dl>
                {issue.withdrawal_reason ? (
                  <p className="mt-3 text-sm text-slate-600">
                    Причина отзыва: {issue.withdrawal_reason}
                  </p>
                ) : null}
              </li>
            ))}
          </ol>
        )}
      </section>
    </>
  );
}
