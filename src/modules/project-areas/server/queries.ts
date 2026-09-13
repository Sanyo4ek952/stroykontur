import "server-only";
import { createServerSupabaseClient } from "@/server/supabase/server";

export async function getAreaCapabilities(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: roles } = await supabase
    .from("project_member_roles")
    .select("role_id")
    .eq("project_id", projectId)
    .eq("status", "active");
  const roleIds = [...new Set((roles ?? []).map((row) => row.role_id))];
  if (!roleIds.length) return { canManage: false, canAssign: false };
  const { data: grants } = await supabase
    .from("role_permissions")
    .select("permission_id")
    .in("role_id", roleIds)
    .eq("scope_type", "project");
  const permissionIds = [
    ...new Set((grants ?? []).map((row) => row.permission_id)),
  ];
  if (!permissionIds.length) return { canManage: false, canAssign: false };
  const { data: permissions } = await supabase
    .from("permissions")
    .select("key")
    .in("id", permissionIds)
    .in("key", ["project_area.manage", "project_area.assign_members"]);
  const keys = new Set((permissions ?? []).map((row) => row.key));
  return {
    canManage: keys.has("project_area.manage"),
    canAssign: keys.has("project_area.assign_members"),
  };
}

export async function getProjectAreas(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("project_areas")
    .select("id,code,name,description")
    .eq("project_id", projectId)
    .order("code");
  if (error) throw new Error("Не удалось загрузить зоны работ.");
  const areas = data ?? [];
  const counts = await Promise.all(
    areas.map(async (area) => {
      const { count } = await supabase
        .from("project_member_areas")
        .select("id", { count: "exact", head: true })
        .eq("project_id", projectId)
        .eq("project_area_id", area.id)
        .is("removed_at", null);
      return [area.id, count ?? 0] as const;
    }),
  );
  return areas.map((area) => ({
    ...area,
    activeMemberCount: new Map(counts).get(area.id) ?? 0,
  }));
}

export async function getAreaMembers(projectId: string, areaId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("project_member_areas")
    .select("id,project_member_id,assigned_at,removed_at,removal_reason")
    .eq("project_id", projectId)
    .eq("project_area_id", areaId)
    .order("assigned_at", { ascending: false });
  if (error) throw new Error("Не удалось загрузить назначения зоны.");
  return data ?? [];
}
export async function getAreaCandidates(projectId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("project_area_member_candidates")
    .select("id")
    .eq("project_id", projectId)
    .order("id");
  if (error) throw new Error("Не удалось загрузить участников проекта.");
  return (data ?? []).flatMap((row) =>
    row.id ? [{ id: row.id, label: `Участник ${row.id.slice(0, 8)}` }] : [],
  );
}
