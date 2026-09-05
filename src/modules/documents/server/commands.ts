import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type DocumentCommandErrorCode =
  | "DOCUMENT_DUPLICATE"
  | "DOCUMENT_NOT_FOUND"
  | "FORBIDDEN"
  | "PROJECT_NOT_FOUND"
  | "REVISION_DUPLICATE"
  | "UNEXPECTED";

export class DocumentCommandError extends Error {
  constructor(readonly code: DocumentCommandErrorCode) {
    super(code);
    this.name = "DocumentCommandError";
  }
}

async function requireAccessibleProject(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("projects")
    .select("id")
    .eq("id", projectId)
    .maybeSingle();

  if (error) throw new DocumentCommandError("UNEXPECTED");
  if (!data) throw new DocumentCommandError("PROJECT_NOT_FOUND");
  return supabase;
}

function mapInsertError(
  code: string | undefined,
  duplicateCode: "DOCUMENT_DUPLICATE" | "REVISION_DUPLICATE",
): never {
  if (code === "23505") throw new DocumentCommandError(duplicateCode);
  if (code === "42501") throw new DocumentCommandError("FORBIDDEN");
  throw new DocumentCommandError("UNEXPECTED");
}

export async function createTechnicalDocumentCommand(input: {
  code: string;
  projectId: string;
  title: string;
  userId: string;
}) {
  const supabase = await requireAccessibleProject(input.projectId);
  const id = crypto.randomUUID();
  const { error } = await supabase.from("technical_documents").insert({
    code: input.code,
    created_by: input.userId,
    id,
    project_id: input.projectId,
    title: input.title,
  });

  if (error) mapInsertError(error.code, "DOCUMENT_DUPLICATE");
  return { id };
}

export async function createDocumentRevisionCommand(input: {
  documentId: string;
  projectId: string;
  revisionCode: string;
  userId: string;
}) {
  const supabase = await requireAccessibleProject(input.projectId);
  const { data: document, error: documentError } = await supabase
    .from("technical_documents")
    .select("id")
    .eq("project_id", input.projectId)
    .eq("id", input.documentId)
    .maybeSingle();

  if (documentError) throw new DocumentCommandError("UNEXPECTED");
  if (!document) throw new DocumentCommandError("DOCUMENT_NOT_FOUND");

  const id = crypto.randomUUID();
  const { error } = await supabase.from("document_revisions").insert({
    created_by: input.userId,
    id,
    project_id: input.projectId,
    revision_code: input.revisionCode,
    status: "draft",
    technical_document_id: input.documentId,
  });

  if (error) mapInsertError(error.code, "REVISION_DUPLICATE");
  return { id };
}
