import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

import type { WorkFilters } from "../model/schemas";

function queryError(message: string): never {
  throw new Error(message);
}

function memberLabel(memberId: string, ownMemberId: string | null) {
  return memberId === ownMemberId
    ? "Вы"
    : `Участник проекта · ${memberId.slice(0, 8)}`;
}

async function getOwnProjectMemberId(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("project_members")
    .select("id")
    .eq("project_id", projectId)
    .maybeSingle();

  if (error) queryError("Не удалось загрузить контекст участника проекта.");
  return data?.id ?? null;
}

async function getSearchWorkIds(projectId: string, search: string) {
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

  if (codes.error || titles.error)
    queryError("Не удалось выполнить поиск работ.");
  return [...new Set([...codes.data, ...titles.data].map(({ id }) => id))];
}

export async function getWorks(projectId: string, filters: WorkFilters) {
  const supabase = await createServerSupabaseClient();
  const matchingIds = filters.search
    ? await getSearchWorkIds(projectId, filters.search)
    : null;

  if (matchingIds?.length === 0) return [];

  let query = supabase
    .from("works")
    .select(
      "id, code, title, status, planned_quantity, unit, planned_start_date, planned_finish_date",
    )
    .eq("project_id", projectId)
    .order("code");

  if (matchingIds) query = query.in("id", matchingIds);
  if (filters.status) query = query.eq("status", filters.status);

  const { data: works, error } = await query;
  if (error) queryError("Не удалось загрузить работы проекта.");
  if (works.length === 0) return [];

  const [ownMemberId, assignmentsResult] = await Promise.all([
    getOwnProjectMemberId(projectId),
    supabase
      .from("work_assignments")
      .select("work_id, project_member_id")
      .eq("project_id", projectId)
      .is("ended_at", null)
      .in(
        "work_id",
        works.map(({ id }) => id),
      ),
  ]);

  if (assignmentsResult.error)
    queryError("Не удалось загрузить ответственных.");
  const assignments = new Map(
    assignmentsResult.data.map((assignment) => [
      assignment.work_id,
      assignment,
    ]),
  );

  return works.map((work) => {
    const assignment = assignments.get(work.id);
    return {
      ...work,
      responsibleLabel: assignment
        ? memberLabel(assignment.project_member_id, ownMemberId)
        : null,
    };
  });
}

export async function getWorkDetails(projectId: string, workId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const currentUserId = claimsData?.claims?.sub;
  const { data: work, error } = await supabase
    .from("works")
    .select(
      "id, code, title, status, planned_quantity, unit, planned_start_date, planned_finish_date, created_at, updated_at",
    )
    .eq("project_id", projectId)
    .eq("id", workId)
    .maybeSingle();

  if (error) queryError("Не удалось загрузить работу.");
  if (!work) return null;

  const [ownMemberId, assignmentsResult, dependenciesResult, progressResult] =
    await Promise.all([
      getOwnProjectMemberId(projectId),
      supabase
        .from("work_assignments")
        .select(
          "id, project_member_id, assigned_by, assigned_at, ended_at, end_reason",
        )
        .eq("project_id", projectId)
        .eq("work_id", workId)
        .order("assigned_at", { ascending: false }),
      supabase
        .from("work_dependencies")
        .select("id, dependent_work_id, depends_on_work_id")
        .eq("project_id", projectId)
        .is("removed_at", null)
        .or(`dependent_work_id.eq.${workId},depends_on_work_id.eq.${workId}`),
      supabase
        .from("work_progress_entries")
        .select("id, work_date, quantity, note, created_by, created_at")
        .eq("project_id", projectId)
        .eq("work_id", workId)
        .order("work_date", { ascending: false })
        .order("created_at", { ascending: false }),
    ]);

  if (
    assignmentsResult.error ||
    dependenciesResult.error ||
    progressResult.error
  ) {
    queryError("Не удалось загрузить историю работы.");
  }

  const dependencyWorkIds = [
    ...new Set(
      dependenciesResult.data.map((dependency) =>
        dependency.dependent_work_id === workId
          ? dependency.depends_on_work_id
          : dependency.dependent_work_id,
      ),
    ),
  ];
  const { data: relatedWorks, error: relatedWorksError } =
    dependencyWorkIds.length > 0
      ? await supabase
          .from("works")
          .select("id, code, title, status")
          .eq("project_id", projectId)
          .in("id", dependencyWorkIds)
      : { data: [], error: null };

  if (relatedWorksError) queryError("Не удалось загрузить зависимости работы.");
  const relatedWorksById = new Map(relatedWorks.map((item) => [item.id, item]));

  const assignmentHistory = assignmentsResult.data.map((assignment) => ({
    ...assignment,
    assignedByLabel:
      assignment.assigned_by === currentUserId ? "Вы" : "Пользователь проекта",
    responsibleLabel: memberLabel(assignment.project_member_id, ownMemberId),
  }));

  return {
    ...work,
    assignmentHistory,
    blockedBy: dependenciesResult.data
      .filter((dependency) => dependency.dependent_work_id === workId)
      .map((dependency) => relatedWorksById.get(dependency.depends_on_work_id))
      .filter((item): item is NonNullable<typeof item> => Boolean(item)),
    blocks: dependenciesResult.data
      .filter((dependency) => dependency.depends_on_work_id === workId)
      .map((dependency) => relatedWorksById.get(dependency.dependent_work_id))
      .filter((item): item is NonNullable<typeof item> => Boolean(item)),
    currentAssignment:
      assignmentHistory.find((assignment) => assignment.ended_at === null) ??
      null,
    progress: progressResult.data.map((entry) => ({
      ...entry,
      reporterLabel:
        entry.created_by === currentUserId ? "Вы" : "Пользователь проекта",
    })),
  };
}

export async function getWorkCapabilities(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: assignments, error: assignmentsError } = await supabase
    .from("project_member_roles")
    .select("role_id")
    .eq("project_id", projectId)
    .eq("status", "active");

  if (assignmentsError) queryError("Не удалось проверить права на работы.");
  const assignedRoleIds = [
    ...new Set(assignments.map(({ role_id }) => role_id)),
  ];
  const emptyCapabilities = {
    canAcceptWork: false,
    canBlockWork: false,
    canCloseWork: false,
    canCreateWork: false,
    canMarkWorkReady: false,
    canMarkWorkReadyForInspection: false,
    canRequireWorkRework: false,
    canStartWork: false,
  };
  if (assignedRoleIds.length === 0) return emptyCapabilities;

  const { data: member, error: memberError } = await supabase
    .from("project_members")
    .select("project_organization_id")
    .eq("project_id", projectId)
    .eq("status", "active")
    .maybeSingle();
  if (memberError) queryError("Не удалось проверить права на работы.");
  if (!member) return emptyCapabilities;
  const { data: organization, error: organizationError } = await supabase
    .from("project_organizations")
    .select("id")
    .eq("project_id", projectId)
    .eq("id", member.project_organization_id)
    .eq("status", "active")
    .maybeSingle();
  if (organizationError) queryError("Не удалось проверить права на работы.");
  if (!organization) return emptyCapabilities;

  const { data: roles, error: rolesError } = await supabase
    .from("roles")
    .select("id")
    .in("id", assignedRoleIds)
    .eq("status", "active");

  if (rolesError) queryError("Не удалось проверить права на работы.");
  const roleIds = roles.map(({ id }) => id);
  if (roleIds.length === 0) return emptyCapabilities;

  const { data: grants, error: grantsError } = await supabase
    .from("role_permissions")
    .select("permission_id")
    .in("role_id", roleIds)
    .eq("scope_type", "project");

  if (grantsError) queryError("Не удалось проверить права на работы.");
  const permissionIds = [
    ...new Set(grants.map(({ permission_id }) => permission_id)),
  ];
  if (permissionIds.length === 0) return emptyCapabilities;

  const { data: permissions, error: permissionsError } = await supabase
    .from("permissions")
    .select("key")
    .in("id", permissionIds)
    .in("key", [
      "quality.work.accept",
      "work.block",
      "work.close",
      "work.create",
      "work.ready",
      "work.ready_for_inspection",
      "work.rework",
      "work.start",
    ])
    .eq("status", "active");

  if (permissionsError) queryError("Не удалось проверить права на работы.");
  const keys = new Set(permissions.map(({ key }) => key));
  return {
    canAcceptWork: keys.has("quality.work.accept"),
    canBlockWork: keys.has("work.block"),
    canCloseWork: keys.has("work.close"),
    canCreateWork: keys.has("work.create"),
    canMarkWorkReady: keys.has("work.ready"),
    canMarkWorkReadyForInspection: keys.has("work.ready_for_inspection"),
    canRequireWorkRework: keys.has("work.rework"),
    canStartWork: keys.has("work.start"),
  };
}
