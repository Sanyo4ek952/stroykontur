import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

const openTaskStatuses = [
  "OPEN",
  "ASSIGNED",
  "IN_PROGRESS",
  "BLOCKED",
  "OVERDUE",
  "VERIFICATION",
];

function queryError(message: string): never {
  throw new Error(message);
}

export type AccessibleProject = {
  code: string;
  description: string | null;
  id: string;
  name: string;
  organizationName: string | null;
  organizationRelationship: string | null;
  status: string;
};

export async function getAccessibleProjects(): Promise<AccessibleProject[]> {
  const supabase = await createServerSupabaseClient();
  const { data: projects, error } = await supabase
    .from("projects")
    .select("id, code, name, description, status")
    .order("name");

  if (error) queryError("Не удалось загрузить доступные проекты.");
  if (projects.length === 0) return [];

  const { data: memberships, error: membershipsError } = await supabase
    .from("project_members")
    .select("project_id, project_organization_id")
    .in(
      "project_id",
      projects.map((project) => project.id),
    );

  if (membershipsError) queryError("Не удалось загрузить контекст проектов.");

  const organizationIds = memberships.map(
    (membership) => membership.project_organization_id,
  );
  const { data: projectOrganizations, error: projectOrganizationsError } =
    organizationIds.length > 0
      ? await supabase
          .from("project_organizations")
          .select("id, organization_id, relationship_type")
          .in("id", organizationIds)
      : { data: [], error: null };

  if (projectOrganizationsError) {
    queryError("Не удалось загрузить организации проектов.");
  }

  const canonicalOrganizationIds = projectOrganizations.map(
    (organization) => organization.organization_id,
  );
  const { data: organizations, error: organizationsError } =
    canonicalOrganizationIds.length > 0
      ? await supabase
          .from("organizations")
          .select("id, name")
          .in("id", canonicalOrganizationIds)
      : { data: [], error: null };

  if (organizationsError) queryError("Не удалось загрузить организации.");

  const membershipsByProject = new Map(
    memberships.map((membership) => [membership.project_id, membership]),
  );
  const projectOrganizationsById = new Map(
    projectOrganizations.map((organization) => [organization.id, organization]),
  );
  const organizationsById = new Map(
    organizations.map((organization) => [organization.id, organization]),
  );

  return projects.map((project) => {
    const membership = membershipsByProject.get(project.id);
    const projectOrganization = membership
      ? projectOrganizationsById.get(membership.project_organization_id)
      : undefined;
    const organization = projectOrganization
      ? organizationsById.get(projectOrganization.organization_id)
      : undefined;

    return {
      ...project,
      organizationName: organization?.name ?? null,
      organizationRelationship: projectOrganization?.relationship_type ?? null,
    };
  });
}

export async function getAccessibleProject(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: project, error } = await supabase
    .from("projects")
    .select("id, code, name, description, status, start_date, end_date")
    .eq("id", projectId)
    .maybeSingle();

  if (error) queryError("Не удалось загрузить проект.");
  if (!project) return null;

  const { data: membership, error: membershipError } = await supabase
    .from("project_members")
    .select("id, project_organization_id")
    .eq("project_id", projectId)
    .maybeSingle();

  if (membershipError) queryError("Не удалось загрузить контекст проекта.");

  let organizationName: string | null = null;
  let organizationRelationship: string | null = null;

  if (membership) {
    const { data: projectOrganization, error: projectOrganizationError } =
      await supabase
        .from("project_organizations")
        .select("organization_id, relationship_type")
        .eq("id", membership.project_organization_id)
        .maybeSingle();

    if (projectOrganizationError) {
      queryError("Не удалось загрузить организацию проекта.");
    }

    organizationRelationship = projectOrganization?.relationship_type ?? null;
    if (projectOrganization) {
      const { data: organization, error: organizationError } = await supabase
        .from("organizations")
        .select("name")
        .eq("id", projectOrganization.organization_id)
        .maybeSingle();

      if (organizationError) queryError("Не удалось загрузить организацию.");
      organizationName = organization?.name ?? null;
    }
  }

  return {
    ...project,
    ownProjectMemberId: membership?.id ?? null,
    organizationName,
    organizationRelationship,
  };
}

export async function getProjectOverview(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const [tasks, notifications, documents, works, impacts] = await Promise.all([
    supabase
      .from("tasks")
      .select("id", { count: "exact", head: true })
      .eq("project_id", projectId)
      .in("status", openTaskStatuses),
    supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("project_id", projectId)
      .is("read_at", null),
    supabase
      .from("technical_documents")
      .select("id", { count: "exact", head: true })
      .eq("project_id", projectId),
    supabase
      .from("works")
      .select("id", { count: "exact", head: true })
      .eq("project_id", projectId),
    supabase
      .from("document_impacts")
      .select("id", { count: "exact", head: true })
      .eq("project_id", projectId)
      .eq("status", "DETECTED"),
  ]);

  if (
    tasks.error ||
    notifications.error ||
    documents.error ||
    works.error ||
    impacts.error
  ) {
    queryError("Не удалось загрузить обзор проекта.");
  }

  return {
    documentCount: documents.count ?? 0,
    impactCount: impacts.count ?? 0,
    openTaskCount: tasks.count ?? 0,
    unreadNotificationCount: notifications.count ?? 0,
    workCount: works.count ?? 0,
  };
}

export async function getOwnProjectTasks(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("tasks")
    .select("id, task_type, status, created_at")
    .eq("project_id", projectId)
    .order("created_at", { ascending: false });

  if (error) queryError("Не удалось загрузить ваши задачи.");
  return data;
}

export async function getProjectDocuments(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: documents, error } = await supabase
    .from("technical_documents")
    .select("id, code, title, updated_at")
    .eq("project_id", projectId)
    .order("code");

  if (error) queryError("Не удалось загрузить документы проекта.");
  if (documents.length === 0) return [];

  const documentIds = documents.map((document) => document.id);
  const [revisionResult, issueResult] = await Promise.all([
    supabase
      .from("document_revisions")
      .select("technical_document_id, revision_code, status, created_at")
      .eq("project_id", projectId)
      .in("technical_document_id", documentIds)
      .order("created_at", { ascending: false }),
    supabase
      .from("document_issues_for_work")
      .select(
        "technical_document_id, document_revision_id, issued_at, withdrawn_at",
      )
      .eq("project_id", projectId)
      .in("technical_document_id", documentIds)
      .order("issued_at", { ascending: false }),
  ]);

  if (revisionResult.error || issueResult.error) {
    queryError("Не удалось загрузить состояние документов.");
  }

  return documents.map((document) => ({
    ...document,
    currentIssue: issueResult.data.find(
      (issue) =>
        issue.technical_document_id === document.id && !issue.withdrawn_at,
    ),
    latestRevision: revisionResult.data.find(
      (revision) => revision.technical_document_id === document.id,
    ),
  }));
}

export async function getProjectWorks(
  projectId: string,
  ownProjectMemberId: string | null,
) {
  const supabase = await createServerSupabaseClient();
  const { data: works, error } = await supabase
    .from("works")
    .select(
      "id, code, title, status, planned_quantity, unit, planned_start_date, planned_finish_date",
    )
    .eq("project_id", projectId)
    .order("code");

  if (error) queryError("Не удалось загрузить работы проекта.");
  if (works.length === 0) return [];

  const { data: assignments, error: assignmentsError } = await supabase
    .from("work_assignments")
    .select("work_id, project_member_id")
    .eq("project_id", projectId)
    .is("ended_at", null)
    .in(
      "work_id",
      works.map((work) => work.id),
    );

  if (assignmentsError) queryError("Не удалось загрузить ответственных.");

  return works.map((work) => {
    const assignment = assignments.find(
      (candidate) => candidate.work_id === work.id,
    );
    return {
      ...work,
      responsibleLabel: !assignment
        ? null
        : assignment.project_member_id === ownProjectMemberId
          ? "Вы"
          : "Участник проекта",
    };
  });
}

export async function getOwnProjectNotifications(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: notifications, error } = await supabase
    .from("notifications")
    .select("id, created_at, read_at")
    .eq("project_id", projectId)
    .order("created_at", { ascending: false });

  if (error) queryError("Не удалось загрузить уведомления.");

  return Promise.all(
    notifications.map(async (notification) => {
      const { data, error: sliceError } = await supabase.rpc(
        "get_own_vertical_slice",
        { notification_id: notification.id },
      );

      if (sliceError) queryError("Не удалось загрузить детали уведомления.");
      return { ...notification, scenario: data[0] ?? null };
    }),
  );
}
