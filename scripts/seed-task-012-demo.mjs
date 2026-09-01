import { execFileSync } from "node:child_process";

import { createClient } from "@supabase/supabase-js";

const demoCredentials = {
  email: "demo@construction.test",
  password: "Demo-Task012-2026!",
};

const ids = {
  organization: "00120000-0000-0000-0000-000000000001",
  project: "10120000-0000-0000-0000-000000000001",
  projectOrganization: "20120000-0000-0000-0000-000000000001",
  projectMember: "30120000-0000-0000-0000-000000000001",
  technicalDocument: "50120000-0000-0000-0000-000000000001",
  documentRevision: "60120000-0000-0000-0000-000000000001",
  work: "70120000-0000-0000-0000-000000000001",
  workAssignment: "71120000-0000-0000-0000-000000000001",
  documentWorkLink: "80120000-0000-0000-0000-000000000001",
  documentIssueForWork: "90120000-0000-0000-0000-000000000001",
};

function readLocalSupabaseEnvironment() {
  let output;

  try {
    output = execFileSync(
      process.execPath,
      ["node_modules/supabase/dist/supabase.js", "status", "-o", "env"],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
  } catch {
    throw new Error(
      "Локальный Supabase не запущен. Сначала выполните pnpm db:start.",
    );
  }

  const environment = Object.fromEntries(
    output
      .split(/\r?\n/)
      .map((line) => line.match(/^([A-Z0-9_]+)="?(.*?)"?$/))
      .filter(Boolean)
      .map((match) => [match[1], match[2]]),
  );
  const url = environment.API_URL;
  const privilegedKey = environment.SECRET_KEY ?? environment.SERVICE_ROLE_KEY;
  const publishableKey = environment.PUBLISHABLE_KEY ?? environment.ANON_KEY;

  if (!url || !privilegedKey || !publishableKey) {
    throw new Error(
      "Не удалось получить ключи только что запущенного local Supabase.",
    );
  }

  const parsedUrl = new URL(url);
  if (
    !["127.0.0.1", "localhost", "::1"].includes(parsedUrl.hostname) ||
    parsedUrl.port !== "54321"
  ) {
    throw new Error("Demo seed отказался работать с нелокальным Supabase.");
  }

  return { privilegedKey, publishableKey, url };
}

async function insertOne(client, table, value) {
  const { error } = await client.from(table).insert(value);
  if (error) {
    throw new Error(`Не удалось подготовить ${table}: ${error.code}`);
  }
}

async function findOrCreateDemoUser(adminClient) {
  const { data: existingUsers, error: listError } =
    await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listError) {
    throw new Error(`Не удалось проверить local demo user: ${listError.code}`);
  }

  const existing = existingUsers.users.find(
    (user) => user.email === demoCredentials.email,
  );
  if (existing) {
    const { error } = await adminClient.auth.admin.updateUserById(existing.id, {
      email_confirm: true,
      password: demoCredentials.password,
    });
    if (error) {
      throw new Error(`Не удалось обновить local demo user: ${error.code}`);
    }
    return existing.id;
  }

  const { data, error } = await adminClient.auth.admin.createUser({
    ...demoCredentials,
    email_confirm: true,
  });
  if (error || !data.user) {
    throw new Error(`Не удалось создать local demo user: ${error?.code}`);
  }
  return data.user.id;
}

async function main() {
  const { privilegedKey, publishableKey, url } = readLocalSupabaseEnvironment();
  const adminClient = createClient(url, privilegedKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const userId = await findOrCreateDemoUser(adminClient);

  const { data: existingProject, error: existingProjectError } =
    await adminClient
      .from("projects")
      .select("id")
      .eq("id", ids.project)
      .maybeSingle();
  if (existingProjectError) {
    throw new Error(
      `Не удалось проверить demo scenario: ${existingProjectError.code}`,
    );
  }

  if (!existingProject) {
    await insertOne(adminClient, "organizations", {
      id: ids.organization,
      name: "ООО Генподряд Демонстрация",
    });
    await insertOne(adminClient, "projects", {
      id: ids.project,
      code: "DEMO-012",
      name: "Жилой комплекс Северный квартал",
      status: "active",
    });
    await insertOne(adminClient, "project_organizations", {
      id: ids.projectOrganization,
      project_id: ids.project,
      organization_id: ids.organization,
      relationship_type: "general_contractor",
    });
    await insertOne(adminClient, "project_members", {
      id: ids.projectMember,
      project_id: ids.project,
      project_organization_id: ids.projectOrganization,
      user_id: userId,
    });

    const { data: ptoRole, error: ptoRoleError } = await adminClient
      .from("roles")
      .select("id")
      .eq("code", "pto")
      .single();
    if (ptoRoleError) {
      throw new Error(`Не найдена существующая роль pto: ${ptoRoleError.code}`);
    }
    await insertOne(adminClient, "project_member_roles", {
      project_id: ids.project,
      project_member_id: ids.projectMember,
      role_id: ptoRole.id,
    });
    await insertOne(adminClient, "technical_documents", {
      id: ids.technicalDocument,
      project_id: ids.project,
      code: "КЖ-01",
      title: "Железобетонные конструкции. Фундаментная плита",
      created_by: userId,
    });
    await insertOne(adminClient, "document_revisions", {
      id: ids.documentRevision,
      project_id: ids.project,
      technical_document_id: ids.technicalDocument,
      revision_code: "R2",
      status: "approved",
      created_by: userId,
    });
    await insertOne(adminClient, "works", {
      id: ids.work,
      project_id: ids.project,
      code: "WORK-FND-001",
      title: "Армирование фундаментной плиты секции 1",
      status: "READY",
      created_by: userId,
    });
    await insertOne(adminClient, "work_assignments", {
      id: ids.workAssignment,
      project_id: ids.project,
      work_id: ids.work,
      project_member_id: ids.projectMember,
      assigned_by: userId,
    });
    await insertOne(adminClient, "document_work_links", {
      id: ids.documentWorkLink,
      project_id: ids.project,
      technical_document_id: ids.technicalDocument,
      work_id: ids.work,
      created_by: userId,
    });
    await insertOne(adminClient, "document_issues_for_work", {
      id: ids.documentIssueForWork,
      project_id: ids.project,
      technical_document_id: ids.technicalDocument,
      document_revision_id: ids.documentRevision,
      issued_by: userId,
    });
  }

  const loginClient = createClient(url, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: loginError } =
    await loginClient.auth.signInWithPassword(demoCredentials);
  if (loginError) {
    throw new Error(`Demo credential verification failed: ${loginError.code}`);
  }
  await loginClient.auth.signOut({ scope: "local" });

  const { data: notification, error: notificationError } = await adminClient
    .from("notifications")
    .select("read_at")
    .eq("project_id", ids.project)
    .single();
  if (notificationError) {
    throw new Error(`Demo Notification не создан: ${notificationError.code}`);
  }
  const { count: acknowledgementCount, error: acknowledgementError } =
    await adminClient
      .from("acknowledgements")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project);
  if (acknowledgementError) {
    throw new Error(
      `Не удалось проверить Acknowledgement: ${acknowledgementError.code}`,
    );
  }

  console.log("TASK-012 local demo готов.");
  console.log(`Логин: ${demoCredentials.email}`);
  console.log(`Пароль: ${demoCredentials.password}`);
  console.log(
    notification.read_at === null && acknowledgementCount === 0
      ? "Начальное состояние: Notification unread, Acknowledgement absent."
      : "Сценарий уже использован. Для исходного состояния выполните pnpm db:reset && pnpm demo:seed.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Demo seed failed.");
  process.exitCode = 1;
});
