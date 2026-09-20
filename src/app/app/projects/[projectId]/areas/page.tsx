import type { Metadata } from "next";
import {
  getAreaCandidates,
  getAreaCapabilities,
  getAreaMembers,
  getProjectAreas,
} from "@/modules/project-areas/server/queries";
import { PageIntro, EmptyState, formatDateTime } from "../ui";
import {
  createArea,
  editArea,
  assignAreaMember,
  removeAreaMember,
} from "./actions";
export const metadata: Metadata = { title: "Зоны работ" };
export default async function AreasPage({
  params,
}: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await params;
  const caps = await getAreaCapabilities(projectId);
  if (!caps.canManage && !caps.canAssign)
    return <EmptyState title="Недостаточно прав для управления зонами." />;
  const [areas, candidates] = await Promise.all([
    getProjectAreas(projectId),
    caps.canAssign ? getAreaCandidates(projectId) : Promise.resolve([]),
  ]);
  return (
    <>
      <PageIntro
        eyebrow="Производство"
        title="Зоны работ"
        description="Проектные зоны и исторические назначения участников."
      />
      {caps.canManage ? (
        <form
          action={async (data) => {
            "use server";
            await createArea(projectId, data);
          }}
          className="mb-6 grid gap-3 rounded-2xl border p-4 sm:grid-cols-3"
        >
          <input
            aria-label="Код зоны"
            name="code"
            placeholder="Код зоны"
            required
            className="rounded-xl border p-3"
          />
          <input
            aria-label="Название зоны"
            name="name"
            placeholder="Название зоны"
            required
            className="rounded-xl border p-3"
          />
          <input
            aria-label="Описание зоны"
            name="description"
            placeholder="Описание (необязательно)"
            className="rounded-xl border p-3"
          />
          <button className="rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
            Создать зону
          </button>
        </form>
      ) : null}
      {areas.length === 0 ? (
        <EmptyState title="Зоны работ пока не созданы." />
      ) : (
        <ul className="space-y-4">
          {areas.map(async (area) => {
            const members = await getAreaMembers(projectId, area.id);
            return (
              <li key={area.id} className="rounded-2xl border p-5">
                <p className="text-xs font-bold text-emerald-700">
                  {area.code}
                </p>
                <h2 className="text-xl font-semibold">{area.name}</h2>
                <p className="mt-1 text-slate-600">
                  {area.description ?? "Описание не задано."}
                </p>
                <p className="mt-3 text-sm">
                  Активных участников: {area.activeMemberCount}
                </p>
                {caps.canManage ? (
                  <form
                    action={async (data) => {
                      "use server";
                      await editArea(projectId, data);
                    }}
                    className="mt-4 grid gap-2 sm:grid-cols-3"
                  >
                    <input type="hidden" name="areaId" value={area.id} />
                    <input
                      aria-label={`Название ${area.code}`}
                      name="name"
                      defaultValue={area.name}
                      required
                      className="rounded-xl border p-2"
                    />
                    <input
                      aria-label={`Описание ${area.code}`}
                      name="description"
                      defaultValue={area.description ?? ""}
                      className="rounded-xl border p-2"
                    />
                    <button className="rounded-xl border px-3 py-2 font-semibold">
                      Редактировать
                    </button>
                  </form>
                ) : null}
                {caps.canAssign ? (
                  <form
                    action={async (data) => {
                      "use server";
                      await assignAreaMember(projectId, data);
                    }}
                    className="mt-4 flex flex-wrap gap-2"
                  >
                    <input type="hidden" name="areaId" value={area.id} />
                    <select
                      aria-label={`Участник для ${area.code}`}
                      name="memberId"
                      required
                      className="rounded-xl border p-2"
                    >
                      <option value="">Выберите участника</option>
                      {candidates.map((m) => (
                        <option key={m.id} value={m.id}>
                          {m.label}
                        </option>
                      ))}
                    </select>
                    <button className="rounded-xl border px-3 py-2 font-semibold">
                      Управлять участниками
                    </button>
                  </form>
                ) : null}
                <h3 className="mt-5 font-semibold">История назначений</h3>
                <ul className="mt-2 space-y-2">
                  {members.map((m) => (
                    <li
                      key={m.id}
                      className="rounded-xl bg-slate-50 p-3 text-sm"
                    >
                      Участник {m.project_member_id.slice(0, 8)} · назначен{" "}
                      {formatDateTime(m.assigned_at)}
                      {m.removed_at ? (
                        <>
                          {" "}
                          · снят {formatDateTime(m.removed_at)}:{" "}
                          {m.removal_reason}
                        </>
                      ) : caps.canAssign ? (
                        <form
                          action={async (data) => {
                            "use server";
                            await removeAreaMember(projectId, data);
                          }}
                          className="mt-2 flex gap-2"
                        >
                          <input
                            type="hidden"
                            name="memberAreaId"
                            value={m.id}
                          />
                          <input
                            aria-label="Причина снятия"
                            name="reason"
                            required
                            placeholder="Причина снятия"
                            className="rounded border p-1"
                          />
                          <button className="rounded border px-2">Снять</button>
                        </form>
                      ) : null}
                    </li>
                  ))}
                </ul>
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}
