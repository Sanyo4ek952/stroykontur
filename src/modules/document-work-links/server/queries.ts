import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

function queryError(): never {
  throw new Error("Не удалось загрузить связи документов и работ.");
}

async function getManageCapability(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: assignments, error } = await supabase
    .from("project_member_roles")
    .select("role_id")
    .eq("project_id", projectId)
    .eq("status", "active");
  if (error) queryError();
  const roleIds = [...new Set(assignments.map(({ role_id }) => role_id))];
  if (roleIds.length === 0) return false;

  const { data: roles, error: rolesError } = await supabase
    .from("roles")
    .select("id")
    .in("id", roleIds)
    .eq("status", "active");
  if (rolesError) queryError();
  if (roles.length === 0) return false;

  const { data: grants, error: grantsError } = await supabase
    .from("role_permissions")
    .select("permission_id")
    .in(
      "role_id",
      roles.map(({ id }) => id),
    )
    .eq("scope_type", "project");
  if (grantsError) queryError();
  if (grants.length === 0) return false;

  const { data: permissions, error: permissionsError } = await supabase
    .from("permissions")
    .select("key")
    .in(
      "id",
      grants.map(({ permission_id }) => permission_id),
    )
    .eq("key", "documents.work_link.manage")
    .eq("status", "active");
  if (permissionsError) queryError();
  return permissions.length > 0;
}

async function getMatchingWorkIds(projectId: string, search: string) {
  const supabase = await createServerSupabaseClient();
  const pattern = `%${search.replaceAll("%", "\\%").replaceAll("_", "\\_")}%`;
  const [codes, titles] = await Promise.all([
    supabase
      .from("works")
      .select("id")
      .eq("project_id", projectId)
      .ilike("code", pattern),
    supabase
      .from("works")
      .select("id")
      .eq("project_id", projectId)
      .ilike("title", pattern),
  ]);
  if (codes.error || titles.error) queryError();
  return [...new Set([...codes.data, ...titles.data].map(({ id }) => id))];
}

async function getMatchingDocumentIds(projectId: string, search: string) {
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
  if (codes.error || titles.error) queryError();
  return [...new Set([...codes.data, ...titles.data].map(({ id }) => id))];
}

export async function getDocumentWorkLinkData(
  projectId: string,
  documentId: string,
  search = "",
) {
  const supabase = await createServerSupabaseClient();
  const [canManage, linksResult, issueResult] = await Promise.all([
    getManageCapability(projectId),
    supabase
      .from("document_work_links")
      .select("id, work_id, created_at, removed_at, removal_reason")
      .eq("project_id", projectId)
      .eq("technical_document_id", documentId)
      .order("created_at", { ascending: false }),
    supabase
      .from("document_issues_for_work")
      .select("id")
      .eq("project_id", projectId)
      .eq("technical_document_id", documentId)
      .is("withdrawn_at", null)
      .limit(1),
  ]);
  if (linksResult.error || issueResult.error) queryError();

  const linkedWorkIds = [
    ...new Set(linksResult.data.map(({ work_id }) => work_id)),
  ];
  const { data: linkedWorks, error: linkedWorksError } = linkedWorkIds.length
    ? await supabase
        .from("works")
        .select("id, code, title, status")
        .eq("project_id", projectId)
        .in("id", linkedWorkIds)
    : { data: [], error: null };
  if (linkedWorksError) queryError();
  const worksById = new Map(linkedWorks.map((work) => [work.id, work]));

  const [ownMemberResult, assignmentsResult] = linkedWorkIds.length
    ? await Promise.all([
        supabase
          .from("project_members")
          .select("id")
          .eq("project_id", projectId)
          .maybeSingle(),
        supabase
          .from("work_assignments")
          .select("work_id, project_member_id")
          .eq("project_id", projectId)
          .in("work_id", linkedWorkIds)
          .is("ended_at", null),
      ])
    : [
        { data: null, error: null },
        { data: [], error: null },
      ];
  if (ownMemberResult.error || assignmentsResult.error) queryError();
  const assignmentsByWorkId = new Map(
    assignmentsResult.data.map((assignment) => [
      assignment.work_id,
      assignment,
    ]),
  );

  let candidates: typeof linkedWorks = [];
  if (canManage) {
    const matchingIds = search
      ? await getMatchingWorkIds(projectId, search)
      : null;
    if (!matchingIds || matchingIds.length > 0) {
      let query = supabase
        .from("works")
        .select("id, code, title, status")
        .eq("project_id", projectId)
        .order("code");
      if (matchingIds) query = query.in("id", matchingIds);
      const result = await query;
      if (result.error) queryError();
      const activeIds = new Set(
        linksResult.data
          .filter(({ removed_at }) => !removed_at)
          .map(({ work_id }) => work_id),
      );
      candidates = result.data.filter(({ id }) => !activeIds.has(id));
    }
  }

  return {
    canManage,
    candidates: candidates.map((work) => ({
      ...work,
      hasActiveIssue: issueResult.data.length > 0,
    })),
    hasActiveIssue: issueResult.data.length > 0,
    links: linksResult.data.flatMap((link) => {
      const work = worksById.get(link.work_id);
      if (!work) return [];
      const assignment = assignmentsByWorkId.get(link.work_id);
      return [
        {
          ...link,
          work: {
            ...work,
            responsibleLabel: assignment
              ? assignment.project_member_id === ownMemberResult.data?.id
                ? "Вы"
                : "Участник проекта"
              : null,
          },
        },
      ];
    }),
  };
}

export async function getWorkDocumentLinkData(
  projectId: string,
  workId: string,
  search = "",
) {
  const supabase = await createServerSupabaseClient();
  const [canManage, linksResult] = await Promise.all([
    getManageCapability(projectId),
    supabase
      .from("document_work_links")
      .select(
        "id, technical_document_id, created_at, removed_at, removal_reason",
      )
      .eq("project_id", projectId)
      .eq("work_id", workId)
      .order("created_at", { ascending: false }),
  ]);
  if (linksResult.error) queryError();

  const linkedDocumentIds = [
    ...new Set(
      linksResult.data.map(
        ({ technical_document_id }) => technical_document_id,
      ),
    ),
  ];
  const { data: linkedDocuments, error: linkedDocumentsError } =
    linkedDocumentIds.length
      ? await supabase
          .from("technical_documents")
          .select("id, code, title")
          .eq("project_id", projectId)
          .in("id", linkedDocumentIds)
      : { data: [], error: null };
  if (linkedDocumentsError) queryError();
  const documentsById = new Map(
    linkedDocuments.map((document) => [document.id, document]),
  );

  let candidates: typeof linkedDocuments = [];
  if (canManage) {
    const matchingIds = search
      ? await getMatchingDocumentIds(projectId, search)
      : null;
    if (!matchingIds || matchingIds.length > 0) {
      let query = supabase
        .from("technical_documents")
        .select("id, code, title")
        .eq("project_id", projectId)
        .order("code");
      if (matchingIds) query = query.in("id", matchingIds);
      const result = await query;
      if (result.error) queryError();
      const activeIds = new Set(
        linksResult.data
          .filter(({ removed_at }) => !removed_at)
          .map(({ technical_document_id }) => technical_document_id),
      );
      candidates = result.data.filter(({ id }) => !activeIds.has(id));
    }
  }

  const documentIds = [
    ...new Set([...linkedDocumentIds, ...candidates.map(({ id }) => id)]),
  ];
  const [revisionsResult, issuesResult] = documentIds.length
    ? await Promise.all([
        supabase
          .from("document_revisions")
          .select("technical_document_id, revision_code, status, created_at")
          .eq("project_id", projectId)
          .in("technical_document_id", documentIds)
          .order("created_at", { ascending: false }),
        supabase
          .from("document_issues_for_work")
          .select("technical_document_id")
          .eq("project_id", projectId)
          .in("technical_document_id", documentIds)
          .is("withdrawn_at", null),
      ])
    : [
        { data: [], error: null },
        { data: [], error: null },
      ];
  if (revisionsResult.error || issuesResult.error) queryError();
  const latestRevisions = new Map<
    string,
    (typeof revisionsResult.data)[number]
  >();
  for (const revision of revisionsResult.data) {
    if (!latestRevisions.has(revision.technical_document_id)) {
      latestRevisions.set(revision.technical_document_id, revision);
    }
  }
  const activeIssueIds = new Set(
    issuesResult.data.map(({ technical_document_id }) => technical_document_id),
  );

  return {
    canManage,
    candidates: candidates.map((document) => ({
      ...document,
      hasActiveIssue: activeIssueIds.has(document.id),
    })),
    links: linksResult.data.flatMap((link) => {
      const document = documentsById.get(link.technical_document_id);
      return document
        ? [
            {
              ...link,
              document,
              hasActiveIssue: activeIssueIds.has(document.id),
              latestRevision: latestRevisions.get(document.id) ?? null,
            },
          ]
        : [];
    }),
  };
}
