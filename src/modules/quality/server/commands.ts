import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type QualityInspectionCommandErrorCode =
  | "CONFLICT"
  | "FORBIDDEN"
  | "INVALID_RESULT"
  | "NOT_FOUND"
  | "NOT_INSPECTOR"
  | "STATE_UNAVAILABLE"
  | "UNEXPECTED";

export class QualityInspectionCommandError extends Error {
  constructor(readonly code: QualityInspectionCommandErrorCode) {
    super(code);
    this.name = "QualityInspectionCommandError";
  }
}

function mapError(error: { code?: string }): never {
  if (error.code === "42501")
    throw new QualityInspectionCommandError("FORBIDDEN");
  if (error.code === "P0002")
    throw new QualityInspectionCommandError("NOT_FOUND");
  if (error.code === "QI001")
    throw new QualityInspectionCommandError("CONFLICT");
  if (error.code === "QI004")
    throw new QualityInspectionCommandError("NOT_INSPECTOR");
  if (error.code === "QI005")
    throw new QualityInspectionCommandError("INVALID_RESULT");
  if (
    ["22023", "23505", "QI002", "QI003", "QI006"].includes(error.code ?? "")
  ) {
    throw new QualityInspectionCommandError("STATE_UNAVAILABLE");
  }
  throw new QualityInspectionCommandError("UNEXPECTED");
}

export async function requestWorkInspectionCommand(input: {
  commandId: string;
  workId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("request_work_inspection", {
    p_command_id: input.commandId,
    p_work_id: input.workId,
  });
  if (error) mapError(error);
  return data;
}

export async function scheduleWorkInspectionCommand(input: {
  commandId: string;
  inspectionRequestId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("schedule_work_inspection", {
    p_command_id: input.commandId,
    p_inspection_request_id: input.inspectionRequestId,
  });
  if (error) mapError(error);
  return data;
}

export async function startWorkInspectionCommand(input: {
  commandId: string;
  inspectionId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("start_work_inspection", {
    p_command_id: input.commandId,
    p_inspection_id: input.inspectionId,
  });
  if (error) mapError(error);
  return data;
}

export async function acceptWorkInspectionCommand(input: {
  commandId: string;
  inspectionId: string;
  resultNote: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("accept_work_inspection", {
    p_command_id: input.commandId,
    p_inspection_id: input.inspectionId,
    p_result_note: input.resultNote,
  });
  if (error) mapError(error);
  return data;
}
