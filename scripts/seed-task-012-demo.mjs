import { createHash } from "node:crypto";

import { createClient } from "@supabase/supabase-js";

import {
  demoAccounts,
  demoIds,
  readLocalSupabaseEnvironment,
} from "./local-demo-support.mjs";

const demoCredentials = { ...demoAccounts.pto };
const workCreatorCredentials = { ...demoAccounts.manager };
const fieldCredentials = { ...demoAccounts.field };
const siteManagerCredentials = { ...demoAccounts.siteManager };
const areaBConfirmerCredentials = { ...demoAccounts.areaBConfirmer };
const workQualityCredentials = { ...demoAccounts.quality };
const ids = { ...demoIds };

let actorIdsDifferFromSeed = false;

// Each Playwright attempt owns a fresh project, users and all linked records.
// This option only affects local seed data, never application authorization.
const e2eNamespace = process.argv[2] === "--e2e" ? process.argv[3] : undefined;
if (process.argv.length > 2 && !e2eNamespace?.match(/^[0-9a-f-]{36}$/)) {
  throw new Error("Expected --e2e followed by a UUID namespace.");
}
if (e2eNamespace) {
  for (const key of Object.keys(ids)) {
    const hex = createHash("sha256")
      .update(e2eNamespace + ":" + key)
      .digest("hex");
    ids[key] = [
      hex.slice(0, 8),
      hex.slice(8, 12),
      "4" + hex.slice(13, 16),
      "8" + hex.slice(17, 20),
      hex.slice(20, 32),
    ].join("-");
  }
  for (const credentials of [
    demoCredentials,
    workCreatorCredentials,
    workQualityCredentials,
    fieldCredentials,
    siteManagerCredentials,
    areaBConfirmerCredentials,
  ]) {
    credentials.email = credentials.email.replace(
      "@",
      "+" + e2eNamespace + "@",
    );
  }
}

async function insertOne(client, table, value) {
  const { error } = await client.from(table).insert(value);
  if (error) {
    throw new Error(`Не удалось подготовить ${table}: ${error.code}`);
  }
}

async function findOrCreateDemoUser(adminClient, credentials, expectedId) {
  const { data: existingUsers, error: listError } =
    await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listError) {
    throw new Error(`Не удалось проверить local demo user: ${listError.code}`);
  }

  const existing = existingUsers.users.find(
    (user) => user.email === credentials.email,
  );
  if (existing) {
    actorIdsDifferFromSeed ||= existing.id !== expectedId;
    const { error } = await adminClient.auth.admin.updateUserById(existing.id, {
      email_confirm: true,
      password: credentials.password,
    });
    if (error) {
      throw new Error(`Не удалось обновить local demo user: ${error.code}`);
    }
    return existing.id;
  }

  const { data, error } = await adminClient.auth.admin.createUser({
    ...credentials,
    email_confirm: true,
    id: expectedId,
  });
  if (error || !data.user) {
    throw new Error(`Не удалось создать local demo user: ${error?.code}`);
  }
  return data.user.id;
}

async function ensureAreaMembership(
  adminClient,
  projectMemberId,
  projectAreaId,
  assignedBy,
) {
  const { data, error: readError } = await adminClient
    .from("project_member_areas")
    .select("id")
    .eq("project_id", ids.project)
    .eq("project_member_id", projectMemberId)
    .eq("project_area_id", projectAreaId)
    .is("removed_at", null)
    .maybeSingle();
  if (readError) throw new Error("Не удалось проверить доступ к Area.");
  if (!data) {
    await insertOne(adminClient, "project_member_areas", {
      project_id: ids.project,
      project_member_id: projectMemberId,
      project_area_id: projectAreaId,
      assigned_by: assignedBy,
    });
  }
}

async function ensureTask020Fixture(adminClient, fieldUserId) {
  const { data: fieldMember, error: memberError } = await adminClient
    .from("project_members")
    .select("id, project_organization_id")
    .eq("project_id", ids.project)
    .eq("user_id", fieldUserId)
    .maybeSingle();
  if (memberError) throw new Error("Не удалось проверить полевого участника.");
  const projectMemberId = fieldMember?.id ?? ids.fieldProjectMember;
  if (!fieldMember) {
    await insertOne(adminClient, "project_members", {
      id: projectMemberId,
      project_id: ids.project,
      project_organization_id: ids.subcontractorProjectOrganization,
      user_id: fieldUserId,
      status: "active",
    });
  } else if (
    fieldMember.project_organization_id !== ids.subcontractorProjectOrganization
  ) {
    const { error } = await adminClient
      .from("project_members")
      .update({
        project_organization_id: ids.subcontractorProjectOrganization,
      })
      .eq("id", projectMemberId);
    if (error)
      throw new Error("Не удалось назначить организацию полевому участнику.");
  }
  const { data: masterRole, error: masterRoleError } = await adminClient
    .from("roles")
    .select("id")
    .eq("code", "master")
    .single();
  if (masterRoleError) throw new Error("Не найдена существующая роль master.");
  const { data: ptoRole, error: ptoRoleError } = await adminClient
    .from("roles")
    .select("id")
    .eq("code", "pto")
    .single();
  if (ptoRoleError) throw new Error("Не найдена существующая роль pto.");
  const { error: roleError } = await adminClient
    .from("project_member_roles")
    .upsert(
      [
        {
          project_id: ids.project,
          project_member_id: projectMemberId,
          role_id: masterRole.id,
        },
        {
          project_id: ids.project,
          project_member_id: projectMemberId,
          role_id: ptoRole.id,
        },
      ],
      { onConflict: "project_member_id,role_id", ignoreDuplicates: true },
    );
  if (roleError)
    throw new Error("Не удалось назначить роли полевому участнику.");
  for (const area of [
    { id: ids.areaA, code: "AREA-A", name: "Зона A" },
    { id: ids.areaB, code: "AREA-B", name: "Зона B" },
  ]) {
    const { error } = await adminClient
      .from("project_areas")
      .upsert(
        { ...area, project_id: ids.project, created_by: fieldUserId },
        { onConflict: "id", ignoreDuplicates: true },
      );
    if (error) throw new Error("Не удалось подготовить Area TASK-020.");
  }
  await ensureAreaMembership(
    adminClient,
    projectMemberId,
    ids.areaA,
    fieldUserId,
  );
  const [workA, workB] = await Promise.all([
    adminClient
      .from("works")
      .update({ project_area_id: ids.areaA })
      .eq("project_id", ids.project)
      .eq("id", ids.work),
    adminClient
      .from("works")
      .update({ project_area_id: ids.areaB })
      .eq("project_id", ids.project)
      .eq("id", ids.blockedWork),
  ]);
  if (workA.error || workB.error)
    throw new Error("Не удалось назначить Area работам TASK-020.");
}

async function ensureTask021Fixture(
  adminClient,
  siteManagerUserId,
  areaId = ids.areaA,
  fallbackMemberId = ids.siteManagerProjectMember,
) {
  const { data: member, error: memberError } = await adminClient
    .from("project_members")
    .select("id, project_organization_id")
    .eq("project_id", ids.project)
    .eq("user_id", siteManagerUserId)
    .maybeSingle();
  if (memberError) throw new Error("Не удалось проверить начальника участка.");

  const projectMemberId = member?.id ?? fallbackMemberId;
  if (!member) {
    await insertOne(adminClient, "project_members", {
      id: projectMemberId,
      project_id: ids.project,
      project_organization_id: ids.subcontractorProjectOrganization,
      user_id: siteManagerUserId,
      status: "active",
    });
  } else if (
    member.project_organization_id !== ids.subcontractorProjectOrganization
  ) {
    const { error } = await adminClient
      .from("project_members")
      .update({
        project_organization_id: ids.subcontractorProjectOrganization,
      })
      .eq("id", projectMemberId);
    if (error)
      throw new Error("Не удалось назначить организацию начальнику участка.");
  }

  const { data: siteManagerRole, error: roleError } = await adminClient
    .from("roles")
    .select("id")
    .eq("code", "site_manager")
    .single();
  if (roleError) throw new Error("Не найдена существующая роль site_manager.");
  const { error: assignmentError } = await adminClient
    .from("project_member_roles")
    .upsert(
      {
        project_id: ids.project,
        project_member_id: projectMemberId,
        role_id: siteManagerRole.id,
      },
      { onConflict: "project_member_id,role_id", ignoreDuplicates: true },
    );
  if (assignmentError)
    throw new Error("Не удалось назначить начальника участка.");

  await ensureAreaMembership(
    adminClient,
    projectMemberId,
    areaId,
    siteManagerUserId,
  );
}

async function main() {
  const { privilegedKey, publishableKey, url } = readLocalSupabaseEnvironment();
  const adminClient = createClient(url, privilegedKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const userId = await findOrCreateDemoUser(
    adminClient,
    demoCredentials,
    ids.demoUser,
  );
  const workCreatorUserId = await findOrCreateDemoUser(
    adminClient,
    workCreatorCredentials,
    ids.workCreatorUser,
  );
  const fieldUserId = await findOrCreateDemoUser(
    adminClient,
    fieldCredentials,
    ids.fieldUser,
  );
  const siteManagerUserId = await findOrCreateDemoUser(
    adminClient,
    siteManagerCredentials,
    ids.siteManagerUser,
  );
  const workQualityUserId = await findOrCreateDemoUser(
    adminClient,
    workQualityCredentials,
    ids.workQualityUser,
  );

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
    await insertOne(adminClient, "projects", {
      id: ids.project,
      code: e2eNamespace ? "E2E-" + e2eNamespace : "DEMO-012",
      name: "Жилой комплекс Северный квартал",
      status: "active",
    });
  }

  const { error: organizationsError } = await adminClient
    .from("organizations")
    .upsert(
      [
        { id: ids.organization, name: "Демонстрационная организация Альфа" },
        {
          id: ids.subcontractorOrganization,
          name: "Демонстрационная организация Бета",
        },
      ],
      { onConflict: "id" },
    );
  if (organizationsError)
    throw new Error("Не удалось подготовить demo Organizations.");

  const { error: projectOrganizationsError } = await adminClient
    .from("project_organizations")
    .upsert(
      [
        {
          id: ids.projectOrganization,
          project_id: ids.project,
          organization_id: ids.organization,
          relationship_type: "general_contractor",
          status: "active",
        },
        {
          id: ids.subcontractorProjectOrganization,
          project_id: ids.project,
          organization_id: ids.subcontractorOrganization,
          relationship_type: "subcontractor",
          status: "active",
        },
      ],
      { onConflict: "id" },
    );
  if (projectOrganizationsError)
    throw new Error("Не удалось подготовить demo ProjectOrganizations.");

  if (!existingProject) {
    await insertOne(adminClient, "project_members", {
      id: ids.projectMember,
      project_id: ids.project,
      project_organization_id: ids.projectOrganization,
      user_id: userId,
    });
    await insertOne(adminClient, "project_members", {
      id: ids.workCreatorProjectMember,
      project_id: ids.project,
      project_organization_id: ids.projectOrganization,
      user_id: workCreatorUserId,
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
    const {
      data: constructionDirectorRole,
      error: constructionDirectorRoleError,
    } = await adminClient
      .from("roles")
      .select("id")
      .eq("code", "construction_director")
      .single();
    if (constructionDirectorRoleError) {
      throw new Error(
        `Не найдена существующая роль construction_director: ${constructionDirectorRoleError.code}`,
      );
    }
    await insertOne(adminClient, "project_member_roles", {
      project_id: ids.project,
      project_member_id: ids.workCreatorProjectMember,
      role_id: constructionDirectorRole.id,
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
      planned_quantity: 120,
      unit: "т",
      planned_start_date: "2026-08-20",
      planned_finish_date: "2026-09-20",
      created_by: userId,
    });
    await insertOne(adminClient, "works", {
      id: ids.prerequisiteWork,
      project_id: ids.project,
      code: "WORK-FND-000",
      title: "Подготовка основания фундаментной плиты",
      status: "CLOSED",
      planned_quantity: 800,
      unit: "м²",
      planned_start_date: "2026-08-01",
      planned_finish_date: "2026-08-19",
      created_by: workCreatorUserId,
    });
    await insertOne(adminClient, "works", {
      id: ids.blockedWork,
      project_id: ids.project,
      code: "WORK-FND-002",
      title: "Бетонирование фундаментной плиты секции 1",
      status: "PLANNED",
      planned_quantity: 640,
      unit: "м³",
      planned_start_date: "2026-09-21",
      planned_finish_date: "2026-09-23",
      created_by: workCreatorUserId,
    });
    await insertOne(adminClient, "work_assignments", {
      id: ids.workAssignment,
      project_id: ids.project,
      work_id: ids.work,
      project_member_id: ids.projectMember,
      assigned_by: userId,
    });
    await insertOne(adminClient, "work_assignments", {
      id: ids.blockedWorkAssignment,
      project_id: ids.project,
      work_id: ids.blockedWork,
      project_member_id: ids.workCreatorProjectMember,
      assigned_by: userId,
    });
    await insertOne(adminClient, "work_dependencies", {
      id: ids.workDependencyPrerequisite,
      project_id: ids.project,
      dependent_work_id: ids.work,
      depends_on_work_id: ids.prerequisiteWork,
      created_by: workCreatorUserId,
    });
    await insertOne(adminClient, "work_dependencies", {
      id: ids.workDependencyBlocked,
      project_id: ids.project,
      dependent_work_id: ids.blockedWork,
      depends_on_work_id: ids.work,
      created_by: workCreatorUserId,
    });
    await insertOne(adminClient, "work_progress_entries", {
      id: ids.workProgress,
      project_id: ids.project,
      work_id: ids.work,
      work_date: "2026-09-01",
      quantity: 18.5,
      note: "Смонтирован первый участок армирования.",
      created_by: userId,
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
    await insertOne(adminClient, "technical_documents", {
      id: ids.issueTechnicalDocument,
      project_id: ids.project,
      code: "АР-017",
      title: "Документ для контролируемой выдачи",
      created_by: userId,
    });
    await insertOne(adminClient, "document_revisions", {
      id: ids.issueDocumentRevision,
      project_id: ids.project,
      technical_document_id: ids.issueTechnicalDocument,
      revision_code: "R1",
      status: "approved",
      created_by: userId,
    });
    await insertOne(adminClient, "works", {
      id: ids.issueWork,
      project_id: ids.project,
      code: "WORK-017-E2E",
      title: "Работа для проверки контролируемой выдачи",
      status: "PLANNED",
      created_by: workCreatorUserId,
    });
    await insertOne(adminClient, "work_assignments", {
      id: ids.issueWorkAssignment,
      project_id: ids.project,
      work_id: ids.issueWork,
      project_member_id: ids.workCreatorProjectMember,
      assigned_by: workCreatorUserId,
    });
    await insertOne(adminClient, "document_work_links", {
      id: ids.issueDocumentWorkLink,
      project_id: ids.project,
      technical_document_id: ids.issueTechnicalDocument,
      work_id: ids.issueWork,
      created_by: userId,
    });
  }

  await ensureTask020Fixture(adminClient, fieldUserId);
  await ensureTask021Fixture(adminClient, siteManagerUserId);
  const areaBConfirmerUserId = await findOrCreateDemoUser(
    adminClient,
    areaBConfirmerCredentials,
    ids.areaBConfirmerUser,
  );
  await ensureTask021Fixture(
    adminClient,
    areaBConfirmerUserId,
    ids.areaB,
    ids.areaBConfirmerProjectMember,
  );
  const { error: dailyWorkError } = await adminClient.from("works").upsert(
    {
      id: ids.dailyReportWork,
      project_id: ids.project,
      project_area_id: ids.areaA,
      code: "WORK-022-A2",
      title: "Бетонирование участка зоны A",
      status: "READY",
      planned_quantity: 50,
      unit: "м³",
      created_by: fieldUserId,
    },
    { onConflict: "id", ignoreDuplicates: true },
  );
  if (dailyWorkError)
    throw new Error("Не удалось подготовить вторую работу DailyReport.");

  const { error: qualityWorkError } = await adminClient.from("works").upsert(
    {
      id: ids.qualityWork,
      project_id: ids.project,
      project_area_id: ids.areaA,
      code: "WORK-024-QUALITY",
      title: "Работа для положительной проверки качества",
      status: "READY_FOR_INSPECTION",
      planned_quantity: 12,
      unit: "м³",
      created_by: workCreatorUserId,
    },
    { onConflict: "id", ignoreDuplicates: true },
  );
  if (qualityWorkError)
    throw new Error("Не удалось подготовить Work для контроля качества.");

  // Add TASK-018 fixtures to an existing local demo without resetting history.
  const { data: qualityMember, error: qualityMemberError } = await adminClient
    .from("project_members")
    .select("id")
    .eq("id", ids.workQualityProjectMember)
    .maybeSingle();
  if (qualityMemberError)
    throw new Error("Не удалось проверить участника стройконтроля.");
  if (!qualityMember) {
    await insertOne(adminClient, "project_members", {
      id: ids.workQualityProjectMember,
      project_id: ids.project,
      project_organization_id: ids.projectOrganization,
      user_id: workQualityUserId,
    });
  }
  const { data: qualityRole, error: qualityRoleError } = await adminClient
    .from("roles")
    .select("id")
    .eq("code", "construction_control_engineer")
    .single();
  if (qualityRoleError)
    throw new Error("Не найдена существующая роль стройконтроля.");
  const { error: qualityAssignmentError } = await adminClient
    .from("project_member_roles")
    .upsert(
      {
        project_id: ids.project,
        project_member_id: ids.workQualityProjectMember,
        role_id: qualityRole.id,
      },
      { onConflict: "project_member_id,role_id", ignoreDuplicates: true },
    );
  if (qualityAssignmentError)
    throw new Error("Не удалось назначить локальный стройконтроль.");
  for (const [projectMemberId, projectAreaId, assignedBy] of [
    [ids.projectMember, ids.areaA, userId],
    [ids.workCreatorProjectMember, ids.areaA, workCreatorUserId],
    [ids.workQualityProjectMember, ids.areaA, workQualityUserId],
  ]) {
    await ensureAreaMembership(
      adminClient,
      projectMemberId,
      projectAreaId,
      assignedBy,
    );
  }
  for (const work of [
    {
      id: ids.lifecycleWork,
      code: "WORK-018",
      title: "Работа для полного жизненного цикла",
      status: "PLANNED",
    },
    {
      id: ids.reworkWork,
      code: "WORK-018-REWORK",
      title: "Работа для возврата на доработку",
      status: "READY_FOR_INSPECTION",
    },
  ]) {
    const { error } = await adminClient.from("works").upsert(
      {
        ...work,
        project_id: ids.project,
        created_by: workCreatorUserId,
      },
      { onConflict: "id", ignoreDuplicates: true },
    );
    if (error) throw new Error("Не удалось создать lifecycle demo Work.");
  }
  const { error: lifecycleAreaError } = await adminClient
    .from("works")
    .update({ project_area_id: ids.areaA })
    .eq("project_id", ids.project)
    .eq("id", ids.lifecycleWork);
  if (lifecycleAreaError)
    throw new Error("Не удалось назначить Area lifecycle Work.");
  for (const assignment of [
    {
      id: ids.lifecycleWorkAssignment,
      project_id: ids.project,
      work_id: ids.lifecycleWork,
      project_member_id: ids.workCreatorProjectMember,
      assigned_by: workCreatorUserId,
    },
  ]) {
    const { error } = await adminClient
      .from("work_assignments")
      .upsert(assignment, { onConflict: "id", ignoreDuplicates: true });
    if (error)
      throw new Error("Не удалось назначить ответственного lifecycle Work.");
  }
  for (const link of [
    {
      id: ids.lifecycleDocumentWorkLink,
      project_id: ids.project,
      technical_document_id: ids.technicalDocument,
      work_id: ids.lifecycleWork,
      created_by: userId,
    },
  ]) {
    const { error } = await adminClient
      .from("document_work_links")
      .upsert(link, { onConflict: "id", ignoreDuplicates: true });
    if (error)
      throw new Error("Не удалось связать readiness Work с документом.");
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
  const { error: workCreatorLoginError } =
    await loginClient.auth.signInWithPassword(workCreatorCredentials);
  if (workCreatorLoginError) {
    throw new Error(
      `Work creator credential verification failed: ${workCreatorLoginError.code}`,
    );
  }
  await loginClient.auth.signOut({ scope: "local" });

  const { error: siteManagerLoginError } =
    await loginClient.auth.signInWithPassword(siteManagerCredentials);
  if (siteManagerLoginError) {
    throw new Error("Не удалось проверить вход начальника участка.");
  }
  await loginClient.auth.signOut({ scope: "local" });

  const { error: qualityLoginError } =
    await loginClient.auth.signInWithPassword(workQualityCredentials);
  if (qualityLoginError)
    throw new Error("Не удалось проверить вход стройконтроля.");
  await loginClient.auth.signOut({ scope: "local" });

  const { data: notification, error: notificationError } = await adminClient
    .from("notifications")
    .select("read_at")
    .eq("project_id", ids.project)
    .limit(1)
    .maybeSingle();
  if (notificationError || !notification) {
    throw new Error(
      `Demo Notification не создан: ${notificationError?.code ?? "NOT_FOUND"}`,
    );
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
  const expectedWorkStatuses = new Map([
    [ids.work, "READY"],
    [ids.prerequisiteWork, "CLOSED"],
    [ids.blockedWork, "PLANNED"],
    [ids.issueWork, "PLANNED"],
    [ids.dailyReportWork, "READY"],
    [ids.qualityWork, "READY_FOR_INSPECTION"],
    [ids.lifecycleWork, "PLANNED"],
    [ids.reworkWork, "READY_FOR_INSPECTION"],
  ]);
  const [
    worksState,
    dailyReportsState,
    blockersState,
    inspectionRequestsState,
    inspectionsState,
    progressState,
  ] = await Promise.all([
    adminClient
      .from("works")
      .select("id, status")
      .eq("project_id", ids.project)
      .in("id", [...expectedWorkStatuses.keys()]),
    adminClient
      .from("daily_reports")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project),
    adminClient
      .from("work_blockers")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project),
    adminClient
      .from("inspection_requests")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project),
    adminClient
      .from("inspections")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project),
    adminClient
      .from("work_progress_entries")
      .select("id", { count: "exact", head: true })
      .eq("project_id", ids.project),
  ]);
  for (const result of [
    worksState,
    dailyReportsState,
    blockersState,
    inspectionRequestsState,
    inspectionsState,
    progressState,
  ]) {
    if (result.error)
      throw new Error("Не удалось проверить начальное состояние demo.");
  }
  const workStatusesAreInitial =
    worksState.data?.length === expectedWorkStatuses.size &&
    worksState.data.every(
      (work) => expectedWorkStatuses.get(work.id) === work.status,
    );
  const scenarioIsInitial =
    !actorIdsDifferFromSeed &&
    notification.read_at === null &&
    acknowledgementCount === 0 &&
    dailyReportsState.count === 0 &&
    blockersState.count === 0 &&
    inspectionRequestsState.count === 0 &&
    inspectionsState.count === 0 &&
    progressState.count === 1 &&
    workStatusesAreInitial;

  if (e2eNamespace) {
    console.log(
      JSON.stringify({
        namespace: e2eNamespace,
        ids,
        demoUser: demoCredentials,
        manager: workCreatorCredentials,
        quality: workQualityCredentials,
        field: fieldCredentials,
        siteManager: siteManagerCredentials,
        areaBConfirmer: areaBConfirmerCredentials,
      }),
    );
    return;
  }

  console.log("TASK-026 local demo готов.");
  console.log(`Логин: ${demoCredentials.email}`);
  console.log(`Пароль: ${demoCredentials.password}`);
  console.log(`Логин для создания Work: ${workCreatorCredentials.email}`);
  console.log(`Пароль для создания Work: ${workCreatorCredentials.password}`);
  console.log("Логин стройконтроля: " + workQualityCredentials.email);
  console.log("Логин начальника участка: " + siteManagerCredentials.email);
  console.log("Логин полевого пользователя: " + fieldCredentials.email);
  console.log("Пароль полевого пользователя: " + fieldCredentials.password);
  console.log(`Пароль стройконтроля: ${workQualityCredentials.password}`);
  console.log(
    scenarioIsInitial
      ? "Начальное состояние: Notification unread, Acknowledgement absent."
      : "Сценарий уже использован. Для исходного состояния выполните pnpm db:reset && pnpm demo:seed.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Demo seed failed.");
  process.exitCode = 1;
});
