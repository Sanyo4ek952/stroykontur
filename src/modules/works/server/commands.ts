import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type WorkCommandErrorCode =
  | "BLOCKER_STALE"
  | "BLOCKER_UNAVAILABLE"
  | "FORBIDDEN"
  | "INVALID_DATES"
  | "INVALID_QUANTITY_UNIT"
  | "PROJECT_NOT_FOUND"
  | "TRANSITION_UNAVAILABLE"
  | "UNEXPECTED"
  | "WORK_DUPLICATE"
  | "WORK_NOT_FOUND"
  | "PROGRESS_STALE"
  | "PROGRESS_UNAVAILABLE"
  | "READINESS_FAILED";

export class WorkCommandError extends Error {
  constructor(readonly code: WorkCommandErrorCode) {
    super(code);
    this.name = "WorkCommandError";
  }
}

async function requireAccessibleProject(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("projects")
    .select("id")
    .eq("id", projectId)
    .maybeSingle();

  if (error) throw new WorkCommandError("UNEXPECTED");
  if (!data) throw new WorkCommandError("PROJECT_NOT_FOUND");
  return supabase;
}

function mapInsertError(error: { code?: string; message?: string }): never {
  if (error.code === "23505") throw new WorkCommandError("WORK_DUPLICATE");
  if (error.code === "42501") throw new WorkCommandError("FORBIDDEN");
  if (error.message?.includes("works_planned_date_range_check")) {
    throw new WorkCommandError("INVALID_DATES");
  }
  if (
    error.message?.includes("works_planned_quantity_positive_check") ||
    error.message?.includes("works_quantity_unit_pair_check") ||
    error.message?.includes("works_unit_not_blank_check")
  ) {
    throw new WorkCommandError("INVALID_QUANTITY_UNIT");
  }
  throw new WorkCommandError("UNEXPECTED");
}

function mapLifecycleError(error: { code?: string }): never {
  if (error.code === "42501") throw new WorkCommandError("FORBIDDEN");
  if (error.code === "P0002") throw new WorkCommandError("WORK_NOT_FOUND");
  if (error.code === "WR001") throw new WorkCommandError("READINESS_FAILED");
  if (error.code === "22023")
    throw new WorkCommandError("TRANSITION_UNAVAILABLE");
  if (["WB005", "WB006"].includes(error.code ?? ""))
    throw new WorkCommandError("TRANSITION_UNAVAILABLE");
  throw new WorkCommandError("UNEXPECTED");
}

function mapBlockerError(error: { code?: string }): never {
  if (error.code === "42501") throw new WorkCommandError("FORBIDDEN");
  if (error.code === "P0002") throw new WorkCommandError("WORK_NOT_FOUND");
  if (error.code === "WB004") throw new WorkCommandError("BLOCKER_STALE");
  if (["22023", "WB002", "WB003"].includes(error.code ?? "")) {
    throw new WorkCommandError("BLOCKER_UNAVAILABLE");
  }
  throw new WorkCommandError("UNEXPECTED");
}

export async function openWorkBlockerCommand(input: {
  category: string;
  commandId: string;
  description: string;
  title: string;
  workId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("open_work_blocker", {
    p_category: input.category,
    p_command_id: input.commandId,
    p_description: input.description,
    p_title: input.title,
    p_work_id: input.workId,
  });
  if (error) mapBlockerError(error);
  return data;
}

export async function resolveWorkBlockerCommand(input: {
  commandId: string;
  resolutionNote: string;
  workBlockerId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("resolve_work_blocker", {
    p_command_id: input.commandId,
    p_resolution_note: input.resolutionNote,
    p_work_blocker_id: input.workBlockerId,
  });
  if (error) mapBlockerError(error);
  return data;
}

export async function reportWorkProgressCommand(input: {
  workId: string;
  quantity: number;
  recordedForDate: string | null;
  note: string | null;
  commandId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("report_work_progress", {
    p_work_id: input.workId,
    p_quantity: input.quantity,
    p_recorded_for_date: input.recordedForDate ?? (null as never),
    p_note: input.note ?? (null as never),
    p_command_id: input.commandId,
  });
  if (error) {
    if (["42501", "P0002", "22023", "WP002"].includes(error.code ?? "")) {
      throw new WorkCommandError("PROGRESS_UNAVAILABLE");
    }
    throw new WorkCommandError("UNEXPECTED");
  }
}

function mapProgressDecisionError(error: { code?: string }): never {
  if (error.code === "WP003") throw new WorkCommandError("PROGRESS_STALE");
  if (["42501", "P0002", "22023", "WP002"].includes(error.code ?? "")) {
    throw new WorkCommandError("PROGRESS_UNAVAILABLE");
  }
  throw new WorkCommandError("UNEXPECTED");
}

export async function confirmWorkProgressCommand(input: {
  commandId: string;
  workProgressEntryId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("confirm_work_progress", {
    p_command_id: input.commandId,
    p_work_progress_entry_id: input.workProgressEntryId,
  });
  if (error) mapProgressDecisionError(error);
}

export async function returnWorkProgressCommand(input: {
  commandId: string;
  reason: string;
  workProgressEntryId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("return_work_progress", {
    p_command_id: input.commandId,
    p_reason: input.reason,
    p_work_progress_entry_id: input.workProgressEntryId,
  });
  if (error) mapProgressDecisionError(error);
}

export async function markWorkReadyCommand(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("mark_work_ready", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function startWorkCommand(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("start_work", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function blockWorkCommand(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("block_work", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function resumeBlockedWorkCommand(
  projectId: string,
  workId: string,
) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("resume_blocked_work", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function markWorkReadyForInspectionCommand(
  projectId: string,
  workId: string,
) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("mark_work_ready_for_inspection", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function requireWorkReworkCommand(
  projectId: string,
  workId: string,
) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("require_work_rework", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function acceptWorkCommand(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("accept_work", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function closeWorkCommand(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("close_work", {
    p_project_id: projectId,
    p_work_id: workId,
  });
  if (error) mapLifecycleError(error);
}

export async function createWorkCommand(input: {
  code: string;
  plannedFinishDate: string | null;
  plannedQuantity: number | null;
  plannedStartDate: string | null;
  projectId: string;
  title: string;
  unit: string | null;
  userId: string;
}) {
  const supabase = await requireAccessibleProject(input.projectId);
  const id = crypto.randomUUID();
  const { error } = await supabase.from("works").insert({
    code: input.code,
    created_by: input.userId,
    id,
    planned_finish_date: input.plannedFinishDate,
    planned_quantity: input.plannedQuantity,
    planned_start_date: input.plannedStartDate,
    project_id: input.projectId,
    status: "PLANNED",
    title: input.title,
    unit: input.unit,
  });

  if (error) mapInsertError(error);
  return { id };
}
