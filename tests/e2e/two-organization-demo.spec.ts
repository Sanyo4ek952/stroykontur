import { createClient } from "@supabase/supabase-js";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { expect, test, type Credentials } from "./fixtures";

async function login(
  page: import("@playwright/test").Page,
  credentials: Credentials,
) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}

async function clientFor(credentials: Credentials) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  if (!["127.0.0.1", "localhost"].includes(new URL(url).hostname)) {
    throw new Error("Local Supabase only.");
  }
  const client = createClient(
    url,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error } = await client.auth.signInWithPassword(credentials);
  expect(error).toBeNull();
  return client;
}

test("seed is deterministic and keeps every actor in the expected organization, role and Area", async ({
  scenario,
}) => {
  test.setTimeout(90_000);
  const { stdout } = await promisify(execFile)(process.execPath, [
    "scripts/seed-task-012-demo.mjs",
    "--e2e",
    scenario.namespace,
  ]);
  const repeated = JSON.parse(stdout.trim()) as typeof scenario;
  expect(repeated.ids).toEqual(scenario.ids);

  const actors = [
    {
      credentials: scenario.demoUser,
      memberId: scenario.ids.projectMember,
      projectOrganizationId: scenario.ids.projectOrganization,
      areaId: scenario.ids.areaA,
      roles: ["pto"],
    },
    {
      credentials: scenario.manager,
      memberId: scenario.ids.workCreatorProjectMember,
      projectOrganizationId: scenario.ids.projectOrganization,
      areaId: scenario.ids.areaA,
      roles: ["construction_director"],
    },
    {
      credentials: scenario.quality,
      memberId: scenario.ids.workQualityProjectMember,
      projectOrganizationId: scenario.ids.projectOrganization,
      areaId: scenario.ids.areaA,
      roles: ["construction_control_engineer"],
    },
    {
      credentials: scenario.field,
      memberId: scenario.ids.fieldProjectMember,
      projectOrganizationId: scenario.ids.subcontractorProjectOrganization,
      areaId: scenario.ids.areaA,
      roles: ["master", "pto"],
    },
    {
      credentials: scenario.siteManager,
      memberId: scenario.ids.siteManagerProjectMember,
      projectOrganizationId: scenario.ids.subcontractorProjectOrganization,
      areaId: scenario.ids.areaA,
      roles: ["site_manager"],
    },
    {
      credentials: scenario.areaBConfirmer,
      memberId: scenario.ids.areaBConfirmerProjectMember,
      projectOrganizationId: scenario.ids.subcontractorProjectOrganization,
      areaId: scenario.ids.areaB,
      roles: ["site_manager"],
    },
  ];

  const topologyClient = await clientFor(scenario.demoUser);
  const projectOrganizations = await topologyClient
    .from("project_organizations")
    .select("id, organization_id, relationship_type, status")
    .eq("project_id", scenario.ids.project)
    .order("id");
  expect(projectOrganizations.error).toBeNull();
  expect(projectOrganizations.data).toEqual(
    [
      {
        id: scenario.ids.projectOrganization,
        organization_id: scenario.ids.organization,
        relationship_type: "general_contractor",
        status: "active",
      },
      {
        id: scenario.ids.subcontractorProjectOrganization,
        organization_id: scenario.ids.subcontractorOrganization,
        relationship_type: "subcontractor",
        status: "active",
      },
    ].sort((left, right) => left.id.localeCompare(right.id)),
  );

  for (const actor of actors) {
    const client = await clientFor(actor.credentials);
    const membership = await client
      .from("project_members")
      .select("id, project_organization_id")
      .eq("project_id", scenario.ids.project)
      .single();
    expect(membership.error).toBeNull();
    expect(membership.data).toEqual({
      id: actor.memberId,
      project_organization_id: actor.projectOrganizationId,
    });

    const areas = await client
      .from("project_member_areas")
      .select("project_area_id")
      .eq("project_id", scenario.ids.project)
      .eq("project_member_id", actor.memberId)
      .is("removed_at", null);
    expect(areas.error).toBeNull();
    expect(areas.data).toEqual([{ project_area_id: actor.areaId }]);

    const roles = await client
      .from("project_member_roles")
      .select("roles(code)")
      .eq("project_id", scenario.ids.project)
      .eq("project_member_id", actor.memberId)
      .eq("status", "active");
    expect(roles.error).toBeNull();
    expect(
      roles.data
        ?.flatMap((assignment) => assignment.roles ?? [])
        .map((role) => role.code)
        .sort(),
    ).toEqual(actor.roles.toSorted());
  }

  const areaBClient = await clientFor(scenario.areaBConfirmer);
  const denied = await areaBClient.rpc("create_daily_report", {
    p_project_area_id: scenario.ids.areaA,
    p_report_date: "2026-09-19",
    p_workers_count: 1,
    p_summary: "Проверка изоляции демонстрационного сценария",
    p_problems: "",
    p_command_id: crypto.randomUUID(),
  });
  expect(denied.error?.code).toBe("42501");
});

test("local entry point warns about network limits", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("Локальное демо")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Краткий сценарий двух организаций" }),
  ).toBeVisible();
  await expect(page.getByRole("note")).toContainText(
    "localhost сам по себе недоступен",
  );
  await expect(page.getByRole("note")).toContainText(
    "PWA не означает offline sync",
  );
});

test("two organizational actors see only their permitted controls and data", async ({
  page,
  scenario,
}) => {
  test.setTimeout(60_000);
  const projectPath = `/app/projects/${scenario.ids.project}`;

  await login(page, scenario.manager);
  const managerProject = page
    .getByRole("listitem")
    .filter({ hasText: "Жилой комплекс Северный квартал" });
  await expect(managerProject).toContainText(
    "Демонстрационная организация Альфа",
  );
  await expect(managerProject).toContainText("Генподрядчик");
  await page.goto(`${projectPath}/works`);
  await expect(
    page.getByRole("link", { name: "Создать работу" }),
  ).toBeVisible();
  await expect(page.getByText("WORK-FND-002", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Выйти" }).click();
  await expect(page).toHaveURL(/\/login$/);

  await login(page, scenario.field);
  const subcontractorProject = page
    .getByRole("listitem")
    .filter({ hasText: "Жилой комплекс Северный квартал" });
  await expect(subcontractorProject).toContainText(
    "Демонстрационная организация Бета",
  );
  await expect(subcontractorProject).toContainText("Субподрядчик");
  await page.goto(`${projectPath}/works`);
  await expect(page.getByRole("link", { name: "Создать работу" })).toHaveCount(
    0,
  );
  await expect(page.getByText("WORK-FND-001", { exact: true })).toBeVisible();
  await expect(page.getByText("WORK-FND-002", { exact: true })).toBeVisible();
  await page.goto(`${projectPath}/daily-reports`);
  await expect(page.getByRole("link", { name: "Создать отчёт" })).toBeVisible();
  await page.getByRole("link", { name: "Создать отчёт" }).click();
  await expect(page.getByLabel("Зона").locator("option")).toHaveCount(1);
  await expect(page.getByLabel("Зона")).toContainText("AREA-A · Зона A");
  await expect(page.getByLabel("Зона")).not.toContainText("AREA-B");
});
