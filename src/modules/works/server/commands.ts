import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type WorkCommandErrorCode =
  | "FORBIDDEN"
  | "INVALID_DATES"
  | "INVALID_QUANTITY_UNIT"
  | "PROJECT_NOT_FOUND"
  | "UNEXPECTED"
  | "WORK_DUPLICATE";

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
