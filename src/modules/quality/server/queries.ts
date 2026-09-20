import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

function queryError(): never {
  throw new Error("Не удалось загрузить контроль качества.");
}

function memberLabel(memberId: string, ownMemberId: string | null) {
  return memberId === ownMemberId
    ? "Вы"
    : `Участник проекта · ${memberId.slice(0, 8)}`;
}

export async function getWorkQualityInspections(
  projectId: string,
  workId: string,
) {
  const supabase = await createServerSupabaseClient();
  const [memberResult, requestsResult, inspectionsResult] = await Promise.all([
    supabase
      .from("project_members")
      .select("id")
      .eq("project_id", projectId)
      .eq("status", "active")
      .maybeSingle(),
    supabase
      .from("inspection_requests")
      .select(
        "id, status, requested_by_project_member_id, requested_at, scheduled_by_project_member_id, scheduled_at, created_at",
      )
      .eq("project_id", projectId)
      .eq("work_id", workId)
      .order("created_at", { ascending: false }),
    supabase
      .from("inspections")
      .select(
        "id, inspection_request_id, status, inspector_project_member_id, scheduled_at, started_at, accepted_at, result_note",
      )
      .eq("project_id", projectId)
      .eq("work_id", workId)
      .order("created_at", { ascending: false }),
  ]);
  if (memberResult.error || requestsResult.error || inspectionsResult.error) {
    queryError();
  }
  const ownMemberId = memberResult.data?.id ?? null;
  const inspections = new Map(
    inspectionsResult.data.map((inspection) => [
      inspection.inspection_request_id,
      {
        ...inspection,
        inspectorLabel: memberLabel(
          inspection.inspector_project_member_id,
          ownMemberId,
        ),
      },
    ]),
  );
  return requestsResult.data.map((request) => ({
    ...request,
    requestedByLabel: memberLabel(
      request.requested_by_project_member_id,
      ownMemberId,
    ),
    scheduledByLabel: request.scheduled_by_project_member_id
      ? memberLabel(request.scheduled_by_project_member_id, ownMemberId)
      : null,
    inspection: inspections.get(request.id) ?? null,
  }));
}

export async function getQualityInspectionCapabilities(
  projectId: string,
  projectAreaId: string | null,
) {
  const empty = {
    canAccept: false,
    canPerform: false,
    canRequest: false,
    ownProjectMemberId: null as string | null,
  };
  const supabase = await createServerSupabaseClient();
  const { data: member, error: memberError } = await supabase
    .from("project_members")
    .select("id, project_organization_id")
    .eq("project_id", projectId)
    .eq("status", "active")
    .maybeSingle();
  if (memberError || !member) return empty;
  const [organizationResult, rolesResult, areaResult] = await Promise.all([
    supabase
      .from("project_organizations")
      .select("id")
      .eq("project_id", projectId)
      .eq("id", member.project_organization_id)
      .eq("status", "active")
      .maybeSingle(),
    supabase
      .from("project_member_roles")
      .select("role_id")
      .eq("project_id", projectId)
      .eq("project_member_id", member.id)
      .eq("status", "active"),
    projectAreaId
      ? supabase
          .from("project_member_areas")
          .select("id")
          .eq("project_id", projectId)
          .eq("project_member_id", member.id)
          .eq("project_area_id", projectAreaId)
          .is("removed_at", null)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);
  if (
    organizationResult.error ||
    rolesResult.error ||
    areaResult.error ||
    !organizationResult.data ||
    rolesResult.data.length === 0
  ) {
    return { ...empty, ownProjectMemberId: member.id };
  }
  const roleIds = rolesResult.data.map(({ role_id }) => role_id);
  const { data: grants, error: grantsError } = await supabase
    .from("role_permissions")
    .select("permission_id, scope_type")
    .in("role_id", roleIds)
    .in("scope_type", ["area", "project"]);
  if (grantsError || grants.length === 0) {
    return { ...empty, ownProjectMemberId: member.id };
  }
  const { data: permissions, error: permissionsError } = await supabase
    .from("permissions")
    .select("id, key")
    .in("id", [...new Set(grants.map(({ permission_id }) => permission_id))])
    .in("key", [
      "quality.inspection.request",
      "quality.inspection.perform",
      "quality.work.accept",
    ])
    .eq("status", "active");
  if (permissionsError) return { ...empty, ownProjectMemberId: member.id };
  const permissionById = new Map(
    permissions.map((permission) => [permission.id, permission.key]),
  );
  const has = (key: string, scope: "area" | "project") =>
    grants.some(
      (grant) =>
        grant.scope_type === scope &&
        permissionById.get(grant.permission_id) === key,
    );
  return {
    canAccept:
      has("quality.inspection.perform", "project") &&
      has("quality.work.accept", "project"),
    canPerform: has("quality.inspection.perform", "project"),
    canRequest:
      Boolean(areaResult.data) && has("quality.inspection.request", "area"),
    ownProjectMemberId: member.id,
  };
}
