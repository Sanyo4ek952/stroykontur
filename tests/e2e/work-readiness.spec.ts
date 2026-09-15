import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";

import type { Page } from "@playwright/test";

import { expect, test, type Credentials } from "./fixtures";

async function login(page: Page, credentials: Credentials) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}

async function openBlocker(page: Page, title: string) {
  const category = page.getByLabel("Категория");
  if (!(await category.isVisible())) {
    await page.getByText("Добавить блокировку", { exact: true }).click();
  }
  await category.selectOption("TECHNICAL");
  await page.getByLabel("Название").fill(title);
  await page.getByLabel("Описание").fill("Требуется техническое решение");
  await page.getByRole("button", { name: "Открыть блокировку" }).click();
  await expect(page.getByText(title).first()).toBeVisible();
}

async function resolveBlocker(page: Page, title: string, note: string) {
  const blocker = page.getByRole("listitem").filter({ hasText: title }).last();
  await blocker.getByText("Устранить", { exact: true }).click();
  await blocker.getByLabel("Результат устранения").fill(note);
  await blocker.getByRole("button", { name: "Подтвердить устранение" }).click();
  await expect(page.getByText(note)).toBeVisible();
}

test("readiness explains failures and enables READY only after prerequisites pass", async ({
  page,
  scenario,
}) => {
  execFileSync("docker", [
    "exec",
    "supabase_db_construction-pwa",
    "psql",
    "-U",
    "postgres",
    "-d",
    "postgres",
    "-v",
    "ON_ERROR_STOP=1",
    "-c",
    `insert into public.document_work_links(id, project_id, technical_document_id, work_id, created_by) select '${randomUUID()}', '${scenario.ids.project}', '${scenario.ids.technicalDocument}', '${scenario.ids.blockedWork}', user_id from public.project_members where id='${scenario.ids.workCreatorProjectMember}'`,
  ]);
  await login(page, scenario.manager);
  const path = `/app/projects/${scenario.ids.project}/works/${scenario.ids.blockedWork}`;
  await page.goto(path);
  const readiness = page
    .getByRole("heading", { name: "Готовность к работе" })
    .locator("../..");
  await expect(readiness.getByText("Не готова", { exact: true })).toBeVisible();
  await expect(
    readiness.getByText(/Не завершена|незавершённые предшествующие работы/i),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Подготовить к работе" }),
  ).toHaveCount(0);

  execFileSync("docker", [
    "exec",
    "supabase_db_construction-pwa",
    "psql",
    "-U",
    "postgres",
    "-d",
    "postgres",
    "-v",
    "ON_ERROR_STOP=1",
    "-c",
    `update public.works set status='ACCEPTED' where id='${scenario.ids.work}'`,
  ]);
  await page.reload();
  await expect(readiness.getByText("Готова", { exact: true })).toBeVisible();
  await page
    .getByRole("button", { name: "Подготовить к работе", exact: true })
    .click();
  await expect(page.getByText("Готова", { exact: true }).first()).toBeVisible();
});
test("blocker prevents START until explicitly resolved", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.manager);
  await page.goto(
    `/app/projects/${scenario.ids.project}/works/${scenario.ids.work}`,
  );
  await openBlocker(page, "Нет доступа к узлу");
  await expect(page.getByText("Готова", { exact: true }).first()).toBeVisible();
  await expect(page.getByRole("heading", { name: "Активные" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Начать работу" })).toHaveCount(
    0,
  );
  await resolveBlocker(page, "Нет доступа к узлу", "Доступ предоставлен");
  await expect(page.getByText("Готова", { exact: true }).first()).toBeVisible();
  await page.getByRole("button", { name: "Начать работу" }).click();
  await expect(
    page.getByText("В работе", { exact: true }).first(),
  ).toBeVisible();
  await page.reload();
  await expect(page.getByText("Доступ предоставлен")).toBeVisible();
});

test("two blockers require two resolutions before explicit resume", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.manager);
  await page.goto(
    `/app/projects/${scenario.ids.project}/works/${scenario.ids.lifecycleWork}`,
  );
  await page.getByRole("button", { name: "Подготовить к работе" }).click();
  await page.getByRole("button", { name: "Начать работу" }).click();
  await openBlocker(page, "Блокировка A");
  await openBlocker(page, "Блокировка B");
  await page.getByRole("button", { name: "Заблокировать работу" }).click();
  await expect(
    page.getByText("Заблокирована", { exact: true }).first(),
  ).toBeVisible();
  await resolveBlocker(page, "Блокировка A", "Причина A устранена");
  await expect(
    page.getByRole("button", { name: "Возобновить работу" }),
  ).toHaveCount(0);
  await resolveBlocker(page, "Блокировка B", "Причина B устранена");
  await expect(
    page.getByText("Заблокирована", { exact: true }).first(),
  ).toBeVisible();
  await page.getByRole("button", { name: "Возобновить работу" }).click();
  await expect(
    page.getByText("В работе", { exact: true }).first(),
  ).toBeVisible();
  await page.reload();
  await expect(page.getByText("Причина A устранена")).toBeVisible();
  await expect(page.getByText("Причина B устранена")).toBeVisible();
});

test("actor without work.block sees history but no blocker controls", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.demoUser);
  await page.goto(
    `/app/projects/${scenario.ids.project}/works/${scenario.ids.work}`,
  );
  await expect(page.getByRole("heading", { name: "Блокировки" })).toBeVisible();
  await expect(
    page.getByText("Добавить блокировку", { exact: true }),
  ).toHaveCount(0);
  await expect(page.getByText("Устранить", { exact: true })).toHaveCount(0);
});
