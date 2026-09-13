import { type Page } from "@playwright/test";
import { expect, test, type Credentials } from "./fixtures";

async function login(page: Page, credentials: Credentials) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}

test("manager reassigns Work atomically and assignment history persists", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.manager);
  const path = `/app/projects/${scenario.ids.project}/works/${scenario.ids.work}`;
  await page.goto(path);
  await page
    .getByRole("button", { name: "Переназначить", exact: true })
    .click();
  const form = page
    .locator("form")
    .filter({ hasText: "Причина переназначения" });
  await form
    .getByRole("combobox")
    .selectOption(scenario.ids.workCreatorProjectMember);
  await form
    .getByLabel("Причина переназначения")
    .fill("Плановая замена ответственного");
  await form.getByRole("button", { name: "Подтвердить назначение" }).click();
  await expect(form.getByRole("status")).toHaveText(
    "Ответственный переназначен.",
  );
  await page.reload();
  await expect(
    page.getByText("Причина: Плановая замена ответственного"),
  ).toBeVisible();
  await expect(
    page.getByText("Основание: Плановая замена ответственного"),
  ).toBeVisible();
});

test("user without work.assign has no WorkAssignment controls", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.demoUser);
  await page.goto(
    `/app/projects/${scenario.ids.project}/works/${scenario.ids.work}`,
  );
  await expect(page.getByRole("button", { name: "Переназначить" })).toHaveCount(
    0,
  );
  await expect(
    page.getByRole("button", { name: "Назначить ответственного" }),
  ).toHaveCount(0);
});
