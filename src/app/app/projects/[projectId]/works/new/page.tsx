import type { Metadata } from "next";

import { getWorkCapabilities } from "@/modules/works/server/queries";

import { PageIntro } from "../../ui";
import { createWork } from "../actions";
import { WorkForm } from "../work-form";

export const metadata: Metadata = { title: "Новая работа" };

export default async function NewWorkPage({
  params,
}: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await params;
  const capabilities = await getWorkCapabilities(projectId);
  const worksPath = `/app/projects/${projectId}/works`;

  return (
    <>
      <PageIntro
        description="Создайте плановую карточку работы без изменения её жизненного цикла."
        eyebrow="Производство"
        title="Новая работа"
      />
      {capabilities.canCreateWork ? (
        <WorkForm
          action={createWork.bind(null, projectId)}
          cancelHref={worksPath}
        />
      ) : (
        <p className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm text-amber-900">
          Недостаточно прав для создания работы.
        </p>
      )}
    </>
  );
}
