"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/server/auth/require-user";
import {
  createProjectArea,
  updateProjectArea,
  assignProjectMemberArea,
  removeProjectMemberArea,
} from "@/modules/project-areas/server/commands";
const uuid = z.string().uuid();
const text = z.string().trim().min(1).max(2000);
export type AreaActionState = { message?: string };
function path(projectId: string) {
  return `/app/projects/${projectId}/areas`;
}
async function run(
  projectId: string,
  fn: () => Promise<void>,
): Promise<AreaActionState> {
  if (!uuid.safeParse(projectId).success)
    return { message: "Проект не найден." };
  await requireUser();
  try {
    await fn();
    revalidatePath(path(projectId));
    return {};
  } catch {
    return { message: "Недостаточно прав или данные зоны недоступны." };
  }
}
export async function createArea(projectId: string, data: FormData) {
  const code = text.safeParse(data.get("code"));
  const name = text.safeParse(data.get("name"));
  if (!code.success || !name.success)
    return { message: "Заполните код и название зоны." };
  return run(projectId, () =>
    createProjectArea({
      projectId,
      code: code.data,
      name: name.data,
      description: String(data.get("description") ?? "").trim() || null,
      commandId: crypto.randomUUID(),
    }),
  );
}
export async function editArea(projectId: string, data: FormData) {
  const id = uuid.safeParse(data.get("areaId"));
  const name = text.safeParse(data.get("name"));
  if (!id.success || !name.success)
    return { message: "Заполните название зоны." };
  return run(projectId, () =>
    updateProjectArea({
      areaId: id.data,
      name: name.data,
      description: String(data.get("description") ?? "").trim() || null,
      commandId: crypto.randomUUID(),
    }),
  );
}
export async function assignAreaMember(projectId: string, data: FormData) {
  const areaId = uuid.safeParse(data.get("areaId"));
  const memberId = uuid.safeParse(data.get("memberId"));
  if (!areaId.success || !memberId.success)
    return { message: "Выберите участника проекта." };
  return run(projectId, () =>
    assignProjectMemberArea({
      areaId: areaId.data,
      memberId: memberId.data,
      commandId: crypto.randomUUID(),
    }),
  );
}
export async function removeAreaMember(projectId: string, data: FormData) {
  const id = uuid.safeParse(data.get("memberAreaId"));
  const reason = text.safeParse(data.get("reason"));
  if (!id.success || !reason.success)
    return { message: "Укажите причину снятия с зоны." };
  return run(projectId, () =>
    removeProjectMemberArea({
      memberAreaId: id.data,
      reason: reason.data,
      commandId: crypto.randomUUID(),
    }),
  );
}
