import type { Page } from "@playwright/test";
import { expect, test, type Credentials } from "./fixtures";
import { createClient } from "@supabase/supabase-js";
import { execFileSync } from "node:child_process";

async function login(page: Page, credentials: Credentials) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}
async function transition(page: Page, label: string, status: string) {
  await page.getByRole("button", { name: label, exact: true }).click();
  await expect(page.getByText(status, { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText(status, { exact: true })).toBeVisible();
}

test("complete lifecycle separates production and quality, persists and confirms closure", async ({
  page,
  browser,
  scenario,
}) => {
  const manager = scenario.manager;
  const quality = scenario.quality;
  const workId = scenario.ids.lifecycleWork;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  test.setTimeout(90_000);
  await login(page, manager);
  await page.goto(`${worksPath}/${workId}`);
  await expect(page.getByRole("combobox")).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Начать работу", exact: true }),
  ).toHaveCount(0);
  await transition(page, "Подготовить к работе", "Готова");
  await transition(page, "Начать работу", "В работе");
  await transition(page, "Заблокировать работу", "Заблокирована");
  await transition(page, "Возобновить работу", "В работе");
  await transition(page, "Передать на проверку", "Готова к проверке");
  await expect(
    page.getByRole("button", { name: "Принять работу" }),
  ).toHaveCount(0);
  const qualityContext = await browser.newContext();
  const qualityPage = await qualityContext.newPage();
  try {
    await login(qualityPage, quality);
    await qualityPage.goto(`${worksPath}/${workId}`);
    await transition(qualityPage, "Принять работу", "Принята");
    await expect(
      qualityPage.getByRole("button", { name: "Закрыть работу" }),
    ).toHaveCount(0);
  } finally {
    await qualityContext.close();
  }
  await page.reload();
  page.once("dialog", (dialog) => dialog.dismiss());
  await page
    .getByRole("button", { name: "Закрыть работу", exact: true })
    .click();
  await expect(page.getByText("Принята", { exact: true })).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await transition(page, "Закрыть работу", "Закрыта");
  await expect(
    page.getByRole("heading", { name: "Действия с работой" }),
  ).toHaveCount(0);
});

test("quality rework needs confirmation and has no undocumented reverse command", async ({
  page,
  scenario,
}) => {
  const quality = scenario.quality;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  await login(page, quality);
  await page.goto(`${worksPath}/${scenario.ids.reworkWork}`);
  page.once("dialog", (dialog) => dialog.dismiss());
  await page.getByRole("button", { name: "Вернуть на доработку" }).click();
  await expect(
    page.getByText("Готова к проверке", { exact: true }),
  ).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await transition(page, "Вернуть на доработку", "Требует исправления");
  await expect(
    page.getByRole("heading", { name: "Действия с работой" }),
  ).toHaveCount(0);
});

test("PTO has no lifecycle controls and foreign Work URLs stay protected", async ({
  page,
  scenario,
}) => {
  const demoUser = scenario.demoUser;
  const workId = scenario.ids.lifecycleWork;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  await login(page, demoUser);
  await page.goto(`${worksPath}/${scenario.ids.work}`);
  await expect(
    page.getByRole("heading", { name: "Действия с работой" }),
  ).toHaveCount(0);
  await page.goto(`${worksPath}/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`);
  await expect(
    page.getByRole("heading", { name: "Работа не найдена." }),
  ).toBeVisible();
  await page.goto(
    `/app/projects/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/works/${workId}`,
  );
  await expect(
    page.getByRole("heading", { name: "Проект не найден" }),
  ).toBeVisible();
});

test("concurrent retries create one history pair; competing commands serialize", async ({
  scenario,
}) => {
  const projectId = scenario.ids.project;
  const manager = scenario.manager;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  // Only the local demo database is eligible for this integration test.
  expect(new URL(url).hostname).toMatch(/^(127\.0\.0\.1|localhost)$/);
  const client = createClient(
    url,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data: auth, error: loginError } =
    await client.auth.signInWithPassword(manager);
  expect(loginError).toBeNull();
  const id = crypto.randomUUID();
  const { error: createError } = await client.from("works").insert({
    id,
    project_id: projectId,
    code: `CONCURRENT-${id}`,
    title: "Проверка конкурентных переходов",
    created_by: auth.user!.id,
  });
  expect(createError).toBeNull();
  const args = { p_project_id: projectId, p_work_id: id };
  const readyResults = await Promise.all([
    client.rpc("mark_work_ready", args),
    client.rpc("mark_work_ready", args),
  ]);
  expect(readyResults.every(({ error }) => error === null)).toBe(true);
  expect((await client.rpc("start_work", args)).error).toBeNull();
  const results = await Promise.all([
    client.rpc("block_work", args),
    client.rpc("mark_work_ready_for_inspection", args),
  ]);
  expect(results.filter(({ error }) => error === null)).toHaveLength(1);
  expect(results.find(({ error }) => error !== null)?.error?.code).toBe(
    "22023",
  );
  // DB-owner access is confined to test assertions, never application runtime.
  const counts = execFileSync(
    "docker",
    [
      "exec",
      "supabase_db_construction-pwa",
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-Atc",
      `select (select count(*) from public.audit_entries where subject_id='${id}'),
      (select count(*) from public.events where subject_id='${id}');`,
    ],
    { encoding: "utf8" },
  ).trim();
  expect(counts).toBe("3|3");
  await client.auth.signOut({ scope: "local" });
});
