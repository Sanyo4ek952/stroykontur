import { createClient } from "@supabase/supabase-js";

import {
  demoAccounts,
  demoIds,
  readLocalProjectConfig,
  readLocalSupabaseEnvironment,
  readPublicEnvironment,
  validateLocalSupabaseUrl,
} from "./local-demo-support.mjs";

function fail(message, error) {
  const suffix = error?.code ? ` (${error.code})` : "";
  throw new Error(`${message}${suffix}`);
}

async function signIn(url, publishableKey, credentials) {
  const client = createClient(url, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await client.auth.signInWithPassword(credentials);
  if (error) fail(`Не удалось войти как ${credentials.email}`, error);
  return client;
}

async function verifyActor({
  client,
  expectedMemberId,
  expectedProjectOrganizationId,
  expectedRole,
}) {
  const membership = await client
    .from("project_members")
    .select("id, project_organization_id")
    .eq("project_id", demoIds.project)
    .single();
  if (membership.error)
    fail("Не удалось проверить demo membership", membership.error);
  if (
    membership.data.id !== expectedMemberId ||
    membership.data.project_organization_id !== expectedProjectOrganizationId
  ) {
    throw new Error("Demo actor привязан к неверной организации проекта.");
  }

  const roles = await client
    .from("project_member_roles")
    .select("roles(code)")
    .eq("project_id", demoIds.project)
    .eq("project_member_id", expectedMemberId)
    .eq("status", "active");
  if (roles.error) fail("Не удалось проверить demo role", roles.error);
  const roleCodes = roles.data.flatMap((assignment) => assignment.roles ?? []);
  if (!roleCodes.some((role) => role.code === expectedRole)) {
    throw new Error(`У demo actor отсутствует роль ${expectedRole}.`);
  }
}

async function verifyRequiredData(adminClient) {
  const [organizations, works, document] = await Promise.all([
    adminClient
      .from("project_organizations")
      .select("id, status")
      .eq("project_id", demoIds.project)
      .eq("status", "active"),
    adminClient
      .from("works")
      .select("id, status")
      .eq("project_id", demoIds.project)
      .in("id", [
        demoIds.work,
        demoIds.blockedWork,
        demoIds.dailyReportWork,
        demoIds.qualityWork,
      ]),
    adminClient
      .from("technical_documents")
      .select("id")
      .eq("project_id", demoIds.project)
      .eq("id", demoIds.technicalDocument)
      .maybeSingle(),
  ]);
  if (organizations.error || works.error || document.error) {
    fail(
      "Не удалось прочитать обязательные demo-данные",
      organizations.error ?? works.error ?? document.error,
    );
  }
  const expectedStatuses = new Map([
    [demoIds.work, "READY"],
    [demoIds.blockedWork, "PLANNED"],
    [demoIds.dailyReportWork, "READY"],
    [demoIds.qualityWork, "READY_FOR_INSPECTION"],
  ]);
  if (
    organizations.data.length !== 2 ||
    works.data.length !== expectedStatuses.size ||
    works.data.some((work) => expectedStatuses.get(work.id) !== work.status) ||
    !document.data
  ) {
    throw new Error(
      "Обязательные demo-данные отсутствуют или сценарий уже изменён. Выполните pnpm demo:prepare.",
    );
  }
}

async function verifyAreaIsolation(managerClient, subcontractorClient) {
  const [managerWorks, subcontractorAreas] = await Promise.all([
    managerClient
      .from("works")
      .select("id")
      .eq("project_id", demoIds.project)
      .eq("id", demoIds.blockedWork),
    subcontractorClient
      .from("daily_report_area_capabilities")
      .select("id, can_report")
      .eq("project_id", demoIds.project),
  ]);
  if (managerWorks.error || subcontractorAreas.error) {
    fail(
      "Не удалось проверить разрешённые demo-данные",
      managerWorks.error ?? subcontractorAreas.error,
    );
  }
  if (managerWorks.data.length !== 1) {
    throw new Error("Директору недоступны project-scoped demo-данные.");
  }
  if (
    subcontractorAreas.data.length !== 1 ||
    subcontractorAreas.data[0].id !== demoIds.areaA ||
    !subcontractorAreas.data[0].can_report
  ) {
    throw new Error("AREA-scope мастера субподрядчика настроен неверно.");
  }
}

async function main() {
  const root = process.cwd();
  const environment = readLocalSupabaseEnvironment({ root });
  const publicEnvironment = readPublicEnvironment(root);
  if (!publicEnvironment) {
    throw new Error("Не найден .env.local. Выполните pnpm demo:prepare.");
  }
  const publicUrl = validateLocalSupabaseUrl(
    publicEnvironment.NEXT_PUBLIC_SUPABASE_URL ?? "",
    readLocalProjectConfig(root),
  );
  if (
    publicUrl !== environment.url ||
    publicEnvironment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY !==
      environment.publishableKey
  ) {
    throw new Error(
      ".env.local не соответствует запущенному local Supabase. Выполните pnpm demo:prepare.",
    );
  }

  let health;
  try {
    health = await fetch(`${environment.url}/auth/v1/health`, {
      headers: { apikey: environment.publishableKey },
      signal: AbortSignal.timeout(5_000),
    });
  } catch {
    throw new Error("Local Supabase endpoint недоступен.");
  }
  if (!health.ok) {
    throw new Error(`Local Supabase endpoint вернул HTTP ${health.status}.`);
  }

  const adminClient = createClient(environment.url, environment.privilegedKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const managerClient = await signIn(
    environment.url,
    environment.publishableKey,
    demoAccounts.manager,
  );
  const subcontractorClient = await signIn(
    environment.url,
    environment.publishableKey,
    demoAccounts.field,
  );

  await Promise.all([
    verifyRequiredData(adminClient),
    verifyActor({
      client: managerClient,
      expectedMemberId: demoIds.workCreatorProjectMember,
      expectedProjectOrganizationId: demoIds.projectOrganization,
      expectedRole: "construction_director",
    }),
    verifyActor({
      client: subcontractorClient,
      expectedMemberId: demoIds.fieldProjectMember,
      expectedProjectOrganizationId: demoIds.subcontractorProjectOrganization,
      expectedRole: "master",
    }),
    verifyAreaIsolation(managerClient, subcontractorClient),
  ]);
  await Promise.all([
    managerClient.auth.signOut({ scope: "local" }),
    subcontractorClient.auth.signOut({ scope: "local" }),
  ]);

  console.log("Локальное демо проверено без изменений бизнес-workflow.");
  console.log("Endpoint: " + environment.url);
  console.log(
    "Обе организации, роли, обязательные данные и AREA-изоляция корректны.",
  );
  console.log("Запуск UI: pnpm dev → http://localhost:3000/");
}

main().catch((error) => {
  console.error(
    error instanceof Error
      ? error.message
      : "Проверка демо завершилась ошибкой.",
  );
  process.exitCode = 1;
});
