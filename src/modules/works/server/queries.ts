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
      "id, code, title, status, planned_quantity, unit, planned_start_date, planned_finish_date, project_area_id",
    )
    .eq("project_id", projectId)
    .order("code");

  if (matchingIds) query = query.in("id", matchingIds);
  if (filters.status) query = query.eq("status", filters.status);

  const { data: works, error } = await query;
  if (error) queryError("Не удалось загрузить работы проекта.");
  if (works.length === 0) return [];

  const [ownMemberId, assignmentsResult, areasResult] = await Promise.all([
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
    supabase
      .from("project_areas")
      .select("id, code, name")
      .eq("project_id", projectId),
  ]);
  if (assignmentsResult.error || areasResult.error)
    queryError("Не удалось загрузить ответственных.");
  const areas = new Map(areasResult.data.map((area) => [area.id, area]));

  const assignments = new Map(
    assignmentsResult.data.map((assignment) => [
      assignment.work_id,
      assignment,
    ]),
  );

  return works.map((work) => {
    const assignment = assignments.get(work.id);
    const area = work.project_area_id ? areas.get(work.project_area_id) : null;
    return {
      ...work,
      areaLabel: area ? `${area.code} · ${area.name}` : "Зона не назначена",
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
      "id, code, title, status, planned_quantity, unit, planned_start_date, planned_finish_date, project_area_id, created_at, updated_at",
    )
    .eq("project_id", projectId)
    .eq("id", workId)
    .maybeSingle();

  if (error) queryError("Не удалось загрузить работу.");
  if (!work) return null;
  const { data: workArea, error: workAreaError } = work.project_area_id
    ? await supabase
        .from("project_areas")
        .select("code, name")
        .eq("project_id", projectId)
        .eq("id", work.project_area_id)
        .maybeSingle()
    : { data: null, error: null };
  if (workAreaError) queryError("Не удалось загрузить зону работы.");

  const [ownMemberId, assignmentsResult, dependenciesResult, progressResult] =
    await Promise.all([
      getOwnProjectMemberId(projectId),
      supabase
        .from("work_assignments")
        .select(
          "id, project_member_id, assigned_by, assigned_at, ended_at, end_reason, assignment_reason",
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
        .select(
          "id, work_date, quantity, note, created_by, created_at, confirmation_status, confirmed_at, confirmed_by, returned_at, returned_by, return_reason",
        )
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
    areaLabel: workArea
      ? `${workArea.code} · ${workArea.name}`
      : "Зона не назначена",
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
      confirmerLabel:
        entry.confirmed_by === null
          ? null
          : entry.confirmed_by === currentUserId
            ? "Вы"
            : "Пользователь проекта",
      returnerLabel:
        entry.returned_by === null
          ? null
          : entry.returned_by === currentUserId
            ? "Вы"
            : "Пользователь проекта",
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
    canAssignWork: false,
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
      "work.assign",
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
    canAssignWork: keys.has("work.assign"),
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

export async function getWorkAssignmentCandidates(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("work_assignment_candidates")
    .select("id")
    .eq("project_id", projectId)
    .order("id");
  if (error) queryError("Не удалось загрузить участников для назначения.");
  return data
    .filter((member): member is { id: string } => member.id !== null)
    .map((member) => ({
      id: member.id,
      label: `Участник проекта · ${member.id.slice(0, 8)}`,
    }));
}

async function canManageWorkProgressInArea(
  projectId: string,
  projectAreaId: string | null,
  permissionKey: "work.progress.report" | "work.progress.confirm",
) {
  if (!projectAreaId) return false;
  const supabase = await createServerSupabaseClient();
  const { data: member, error: memberError } = await supabase
    .from("project_members")
    .select("id")
    .eq("project_id", projectId)
    .eq("status", "active")
    .maybeSingle();
  if (memberError || !member) return false;

  const [rolesResult, areaResult] = await Promise.all([
    supabase
      .from("project_member_roles")
      .select("role_id")
      .eq("project_id", projectId)
      .eq("project_member_id", member.id)
      .eq("status", "active"),
    supabase
      .from("project_member_areas")
      .select("id")
      .eq("project_id", projectId)
      .eq("project_member_id", member.id)
      .eq("project_area_id", projectAreaId)
      .is("removed_at", null)
      .maybeSingle(),
  ]);
  if (
    rolesResult.error ||
    areaResult.error ||
    !areaResult.data ||
    rolesResult.data.length === 0
  ) {
    return false;
  }

  const { data: grants, error: grantsError } = await supabase
    .from("role_permissions")
    .select("permission_id")
    .in(
      "role_id",
      rolesResult.data.map(({ role_id }) => role_id),
    )
    .eq("scope_type", "area");
  if (grantsError || grants.length === 0) return false;

  const { data: permission, error: permissionError } = await supabase
    .from("permissions")
    .select("id")
    .eq("key", permissionKey)
    .eq("status", "active")
    .maybeSingle();
  return (
    !permissionError &&
    permission !== null &&
    grants.some((grant) => grant.permission_id === permission.id)
  );
}

export function canReportWorkProgress(
  projectId: string,
  projectAreaId: string | null,
) {
  return canManageWorkProgressInArea(
    projectId,
    projectAreaId,
    "work.progress.report",
  );
}

export function canConfirmWorkProgress(
  projectId: string,
  projectAreaId: string | null,
) {
  return canManageWorkProgressInArea(
    projectId,
    projectAreaId,
    "work.progress.confirm",
  );
}
