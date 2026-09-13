import "server-only";
import { createServerSupabaseClient } from "@/server/supabase/server";
export class ProjectAreaCommandError extends Error {}
function fail(error: { code?: string } | null) {
  if (error) throw new ProjectAreaCommandError(error.code ?? "UNEXPECTED");
}
export async function createProjectArea(input: {
  projectId: string;
  code: string;
  name: string;
  description: string | null;
  commandId: string;
}) {
  const s = await createServerSupabaseClient();
  const { error } = await s.rpc("create_project_area", {
    p_project_id: input.projectId,
    p_code: input.code,
    p_name: input.name,
    p_description: input.description as never,
    p_command_id: input.commandId,
  });
  fail(error);
}
export async function updateProjectArea(input: {
  areaId: string;
  name: string;
  description: string | null;
  commandId: string;
}) {
  const s = await createServerSupabaseClient();
  const { error } = await s.rpc("update_project_area", {
    p_project_area_id: input.areaId,
    p_name: input.name,
    p_description: input.description as never,
    p_command_id: input.commandId,
  });
  fail(error);
}
export async function assignProjectMemberArea(input: {
  areaId: string;
  memberId: string;
  commandId: string;
}) {
  const s = await createServerSupabaseClient();
  const { error } = await s.rpc("assign_project_member_area", {
    p_project_area_id: input.areaId,
    p_project_member_id: input.memberId,
    p_command_id: input.commandId,
  });
  fail(error);
}
export async function removeProjectMemberArea(input: {
  memberAreaId: string;
  reason: string;
  commandId: string;
}) {
  const s = await createServerSupabaseClient();
  const { error } = await s.rpc("remove_project_member_area", {
    p_project_member_area_id: input.memberAreaId,
    p_reason: input.reason,
    p_command_id: input.commandId,
  });
  fail(error);
}
