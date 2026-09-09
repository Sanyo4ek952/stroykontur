import "server-only";
import { createServerSupabaseClient } from "@/server/supabase/server";
import type { AssignWorkInput, ReassignWorkInput } from "../model/assignment";

export class AssignmentCommandError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}
export async function assignWorkCommand(input: AssignWorkInput) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("assign_work", {
    p_work_id: input.workId,
    p_new_project_member_id: input.newProjectMemberId,
    p_command_id: input.commandId,
    p_reason: input.reason || undefined,
  });
  if (error) throw new AssignmentCommandError(error.code);
  return data;
}
export async function reassignWorkCommand(input: ReassignWorkInput) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("reassign_work", {
    p_work_id: input.workId,
    p_expected_current_assignment_id: input.expectedCurrentAssignmentId,
    p_new_project_member_id: input.newProjectMemberId,
    p_command_id: input.commandId,
    p_reason: input.reason,
  });
  if (error) throw new AssignmentCommandError(error.code);
  return data;
}
