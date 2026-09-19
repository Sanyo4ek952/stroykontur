import Link from "next/link";
export const projectNavigation = [
  { label: "Обзор", segment: "" },
  { label: "Мои задачи", segment: "tasks" },
  { label: "Документы", segment: "documents" },
  { label: "Работы", segment: "works" },
  { label: "Дневные отчёты", segment: "daily-reports" },
  { label: "Уведомления", segment: "notifications" },
] as const;
export function ProjectNavigation({
  projectId,
  showAreas = false,
}: {
  projectId: string;
  showAreas?: boolean;
}) {
  const items = showAreas
    ? [...projectNavigation, { label: "Зоны работ", segment: "areas" }]
    : projectNavigation;
  const basePath = "/app/projects/" + projectId;
  return (
    <nav aria-label="Разделы проекта">
      <ul className="flex gap-2 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible">
        {items.map((item) => (
          <li className="shrink-0" key={item.segment}>
            <Link
              className="flex min-h-11 items-center rounded-xl px-4 text-sm font-semibold text-slate-700 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-3 focus-visible:outline-emerald-600 lg:w-full"
              href={item.segment ? basePath + "/" + item.segment : basePath}
            >
              {item.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
