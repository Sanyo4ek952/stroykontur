import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

import type { DocumentFilters } from "../model/schemas";

function queryError(message: string): never {
  throw new Error(message);
}

function latestByDocument<
  T extends { created_at: string; id: string; technical_document_id: string },
>(rows: T[]) {
  const result = new Map<string, T>();

  for (const row of rows) {
    if (!result.has(row.technical_document_id)) {
      result.set(row.technical_document_id, row);
    }
  }

  return result;
}

async function getSearchDocumentIds(projectId: string, search: string) {
  const supabase = await createServerSupabaseClient();
  const pattern = `%${search.replaceAll("%", "\\%").replaceAll("_", "\\_")}%`;
  const [codes, titles] = await Promise.all([
    supabase
      .from("technical_documents")
      .select("id")
      .eq("project_id", projectId)
      .ilike("code", pattern),
    supabase
      .from("technical_documents")
      .select("id")
      .eq("project_id", projectId)
      .ilike("title", pattern),
  ]);

  if (codes.error || titles.error) {
    queryError("Не удалось выполнить поиск документов.");
  }

  return [...new Set([...codes.data, ...titles.data].map(({ id }) => id))];
}

export async function getDocuments(
  projectId: string,
  filters: DocumentFilters,
) {
  const supabase = await createServerSupabaseClient();
  const matchingIds = filters.search
    ? await getSearchDocumentIds(projectId, filters.search)
    : null;

  if (matchingIds?.length === 0) return [];

  let documentsQuery = supabase
    .from("technical_documents")
    .select("id, code, title, created_at, updated_at")
    .eq("project_id", projectId)
    .order("code");

  if (matchingIds) documentsQuery = documentsQuery.in("id", matchingIds);

  const { data: documents, error } = await documentsQuery;
  if (error) queryError("Не удалось загрузить документы проекта.");
  if (documents.length === 0) return [];

  const documentIds = documents.map(({ id }) => id);
  const { data: revisions, error: revisionsError } = await supabase
    .from("document_revisions")
    .select("id, technical_document_id, revision_code, status, created_at")
    .eq("project_id", projectId)
    .in("technical_document_id", documentIds)
    .order("created_at", { ascending: false })
    .order("id", { ascending: false });

  if (revisionsError) queryError("Не удалось загрузить ревизии документов.");

  const latestRevisions = latestByDocument(revisions);
  const filteredDocuments = filters.status
    ? documents.filter(
        ({ id }) => latestRevisions.get(id)?.status === filters.status,
      )
    : documents;

  if (filteredDocuments.length === 0) return [];

  const filteredDocumentIds = filteredDocuments.map(({ id }) => id);
  const { data: issues, error: issuesError } = await supabase
    .from("document_issues_for_work")
    .select("id, technical_document_id, document_revision_id, issued_at")
    .eq("project_id", projectId)
    .in("technical_document_id", filteredDocumentIds)
    .is("withdrawn_at", null)
    .order("issued_at", { ascending: false });

  if (issuesError) {
    queryError("Не удалось загрузить состояние выдачи документов.");
  }

  const currentIssues = new Map(
    issues.map((issue) => [issue.technical_document_id, issue]),
  );

  return filteredDocuments.map((document) => ({
    ...document,
    currentIssue: currentIssues.get(document.id) ?? null,
    latestRevision: latestRevisions.get(document.id) ?? null,
  }));
}

export async function getDocumentDetails(
  projectId: string,
  documentId: string,
) {
  const supabase = await createServerSupabaseClient();
  const { data: document, error } = await supabase
    .from("technical_documents")
    .select("id, code, title, created_at, updated_at")
    .eq("project_id", projectId)
    .eq("id", documentId)
    .maybeSingle();

  if (error) queryError("Не удалось загрузить документ.");
  if (!document) return null;

  const [revisionsResult, issuesResult] = await Promise.all([
    supabase
      .from("document_revisions")
      .select("id, revision_code, status, created_at")
      .eq("project_id", projectId)
      .eq("technical_document_id", documentId)
      .order("created_at", { ascending: false })
      .order("id", { ascending: false }),
    supabase
      .from("document_issues_for_work")
      .select(
        "id, document_revision_id, issued_at, withdrawn_at, withdrawal_reason",
      )
      .eq("project_id", projectId)
      .eq("technical_document_id", documentId)
      .order("issued_at", { ascending: false }),
  ]);

  if (revisionsResult.error || issuesResult.error) {
    queryError("Не удалось загрузить историю документа.");
  }

  const revisionCodes = new Map(
    revisionsResult.data.map((revision) => [
      revision.id,
      revision.revision_code,
    ]),
  );

  return {
    ...document,
    issues: issuesResult.data.map((issue) => ({
      ...issue,
      revisionCode: revisionCodes.get(issue.document_revision_id) ?? "—",
    })),
    revisions: revisionsResult.data,
  };
}

export async function getDocumentCapabilities(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: assignments, error: assignmentsError } = await supabase
    .from("project_member_roles")
    .select("role_id")
    .eq("project_id", projectId)
    .eq("status", "active");

  if (assignmentsError) queryError("Не удалось проверить права на документы.");
  const assignedRoleIds = [
    ...new Set(assignments.map(({ role_id }) => role_id)),
  ];
  if (assignedRoleIds.length === 0) {
    return {
      canCreateDocument: false,
      canCreateRevision: false,
      canIssueForWork: false,
    };
  }

  const { data: roles, error: rolesError } = await supabase
    .from("roles")
    .select("id")
    .in("id", assignedRoleIds)
    .eq("status", "active");

  if (rolesError) queryError("Не удалось проверить права на документы.");
  const roleIds = roles.map(({ id }) => id);
  if (roleIds.length === 0) {
    return {
      canCreateDocument: false,
      canCreateRevision: false,
      canIssueForWork: false,
    };
  }

  const { data: grants, error: grantsError } = await supabase
    .from("role_permissions")
    .select("permission_id")
    .in("role_id", roleIds)
    .eq("scope_type", "project");

  if (grantsError) queryError("Не удалось проверить права на документы.");
  const permissionIds = [
    ...new Set(grants.map(({ permission_id }) => permission_id)),
  ];
  if (permissionIds.length === 0) {
    return {
      canCreateDocument: false,
      canCreateRevision: false,
      canIssueForWork: false,
    };
  }

  const { data: permissions, error: permissionsError } = await supabase
    .from("permissions")
    .select("key")
    .in("id", permissionIds)
    .in("key", [
      "documents.create",
      "documents.issue_for_work",
      "documents.revision.create",
    ])
    .eq("status", "active");

  if (permissionsError) queryError("Не удалось проверить права на документы.");
  const keys = new Set(permissions.map(({ key }) => key));

  return {
    canCreateDocument: keys.has("documents.create"),
    canCreateRevision: keys.has("documents.revision.create"),
    canIssueForWork: keys.has("documents.issue_for_work"),
  };
}
