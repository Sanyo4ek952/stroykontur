import type { Metadata } from "next";

import { postgresUuidSchema } from "@/modules/documents/model/schemas";

import {
  getDocumentCapabilities,
  getDocumentDetails,
} from "@/modules/documents/server/queries";

import { EmptyState, PageIntro } from "../../../../ui";
import { createDocumentRevision } from "../../../actions";
import { DocumentForm } from "../../../document-form";

export const metadata: Metadata = { title: "Новая ревизия" };

export default async function NewDocumentRevisionPage({
  params,
}: {
  params: Promise<{ documentId: string; projectId: string }>;
}) {
  const { documentId, projectId } = await params;
  const parsedDocumentId = postgresUuidSchema.safeParse(documentId);
  if (!parsedDocumentId.success) {
    return <EmptyState title="Документ не найден." />;
  }

  const [document, capabilities] = await Promise.all([
    getDocumentDetails(projectId, parsedDocumentId.data),
    getDocumentCapabilities(projectId),
  ]);
  if (!document) return <EmptyState title="Документ не найден." />;

  const documentPath = `/app/projects/${projectId}/documents/${document.id}`;

  return (
    <>
      <PageIntro
        description={`${document.code} — ${document.title}`}
        eyebrow="Документация"
        title="Новая ревизия"
      />
      {capabilities.canCreateRevision ? (
        <DocumentForm
          action={createDocumentRevision.bind(
            null,
            projectId,
            parsedDocumentId.data,
          )}
          cancelHref={documentPath}
          kind="revision"
        />
      ) : (
        <p className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm text-amber-900">
          Недостаточно прав для создания ревизии.
        </p>
      )}
    </>
  );
}
