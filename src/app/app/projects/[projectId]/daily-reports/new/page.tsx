import { getDailyReportAreas } from "@/modules/daily-reports/server/queries";
import { postgresUuidSchema } from "@/modules/works/model/schemas";
import { EmptyState, PageIntro } from "../../ui";
import { DailyReportForm } from "../report-controls";

export const metadata = { title: "Новый дневной отчёт" };
export default async function NewDailyReportPage({
  params,
}: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await params;
  if (!postgresUuidSchema.safeParse(projectId).success)
    return <EmptyState title="Проект не найден." />;
  const areas = (await getDailyReportAreas(projectId)).filter(
    (a) => a.can_report,
  );
  if (areas.length === 0)
    return (
      <EmptyState title="Нет прав на создание отчёта в назначенных зонах." />
    );
  return (
    <>
      <PageIntro
        eyebrow="Производство"
        title="Новый дневной отчёт"
        description="Выберите зону и дату. После создания добавьте объёмы по работам этой зоны."
      />
      <DailyReportForm
        projectId={projectId}
        commandId={crypto.randomUUID()}
        areas={areas}
      />
    </>
  );
}
