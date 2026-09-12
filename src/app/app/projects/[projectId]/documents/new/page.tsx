import type { Metadata } from "next";

import { getDocumentCapabilities } from "@/modules/documents/server/queries";

import { PageIntro } from "../../ui";
import { createTechnicalDocument } from "../actions";
import { DocumentForm } from "../document-form";

export const metadata: Metadata = { title: "Новый документ" };

export default async function NewTechnicalDocumentPage({
  params,
}: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await params;
  const capabilities = await getDocumentCapabilities(projectId);
  const documentsPath = `/app/projects/${projectId}/documents`;

  return (
    <>
      <PageIntro
        description="Создайте стабильную карточку документа. Ревизию можно добавить после сохранения."
        eyebrow="Документация"
        title="Новый технический документ"
      />
      {capabilities.canCreateDocument ? (
        <DocumentForm
          action={createTechnicalDocument.bind(null, projectId)}
          cancelHref={documentsPath}
          kind="document"
        />
      ) : (
        <p className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm text-amber-900">
          Недостаточно прав для создания документа.
        </p>
      )}
    </>
  );
}
