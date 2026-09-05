import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type DocumentWorkLinkCommandErrorCode =
  | "ALREADY_REMOVED"
  | "CONFIRMATION_REQUIRED"
  | "DUPLICATE"
  | "ENDPOINT_NOT_FOUND"
  | "FORBIDDEN"
  | "LINK_NOT_FOUND"
  | "UNEXPECTED";

export class DocumentWorkLinkCommandError extends Error {
  constructor(readonly code: DocumentWorkLinkCommandErrorCode) {
    super(code);
    this.name = "DocumentWorkLinkCommandError";
  }
}

function mapMutationError(error: { code?: string }): never {
  if (error.code === "23505") {
    throw new DocumentWorkLinkCommandError("DUPLICATE");
  }
  if (error.code === "42501") {
    throw new DocumentWorkLinkCommandError("FORBIDDEN");
  }
  if (error.code === "23503") {
    throw new DocumentWorkLinkCommandError("ENDPOINT_NOT_FOUND");
  }
  throw new DocumentWorkLinkCommandError("UNEXPECTED");
}

export async function linkDocumentWorkCommand(input: {
  confirmedActiveIssue: boolean;
  documentId: string;
  projectId: string;
  userId: string;
  workId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const [documentResult, workResult, issueResult] = await Promise.all([
    supabase
      .from("technical_documents")
      .select("id")
      .eq("project_id", input.projectId)
      .eq("id", input.documentId)
      .maybeSingle(),
    supabase
      .from("works")
      .select("id")
      .eq("project_id", input.projectId)
      .eq("id", input.workId)
      .maybeSingle(),
    supabase
      .from("document_issues_for_work")
      .select("id")
      .eq("project_id", input.projectId)
      .eq("technical_document_id", input.documentId)
      .is("withdrawn_at", null)
      .limit(1)
      .maybeSingle(),
  ]);

  if (documentResult.error || workResult.error || issueResult.error) {
    throw new DocumentWorkLinkCommandError("UNEXPECTED");
  }
  if (!documentResult.data || !workResult.data) {
    throw new DocumentWorkLinkCommandError("ENDPOINT_NOT_FOUND");
  }
  if (issueResult.data && !input.confirmedActiveIssue) {
    throw new DocumentWorkLinkCommandError("CONFIRMATION_REQUIRED");
  }

  const id = crypto.randomUUID();
  const { error } = await supabase.from("document_work_links").insert({
    created_by: input.userId,
    id,
    project_id: input.projectId,
    technical_document_id: input.documentId,
    work_id: input.workId,
  });

  if (error) mapMutationError(error);
  return { documentId: input.documentId, id, workId: input.workId };
}

export async function unlinkDocumentWorkCommand(input: {
  linkId: string;
  projectId: string;
  reason: string | null;
  userId: string;
}) {
  const supabase = await createServerSupabaseClient();
  const { data: link, error: linkError } = await supabase
    .from("document_work_links")
    .select("technical_document_id, work_id, removed_at")
    .eq("project_id", input.projectId)
    .eq("id", input.linkId)
    .maybeSingle();

  if (linkError) throw new DocumentWorkLinkCommandError("UNEXPECTED");
  if (!link) throw new DocumentWorkLinkCommandError("LINK_NOT_FOUND");
  if (link.removed_at) {
    throw new DocumentWorkLinkCommandError("ALREADY_REMOVED");
  }

  const { data: removed, error } = await supabase
    .from("document_work_links")
    .update({
      removal_reason: input.reason,
      removed_at: new Date().toISOString(),
      removed_by: input.userId,
    })
    .eq("project_id", input.projectId)
    .eq("id", input.linkId)
    .is("removed_at", null)
    .select("id")
    .maybeSingle();

  if (error) mapMutationError(error);
  if (!removed) throw new DocumentWorkLinkCommandError("FORBIDDEN");
  return {
    documentId: link.technical_document_id,
    id: removed.id,
    workId: link.work_id,
  };
}
