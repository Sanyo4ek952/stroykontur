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

test("reports progress only for the assigned Area", async ({
  page,
  scenario,
}) => {
  await login(page, scenario.field);
  const base = `/app/projects/${scenario.ids.project}/works`;
  await page.goto(`${base}/${scenario.ids.work}`);
  await expect(page.getByText("AREA-A · Зона A")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Добавить выполненный объём" }),
  ).toBeVisible();
  await page.getByLabel("Выполненный объём").fill("2.5");
  await page.getByLabel("Примечание").fill("E2E объём");
  await page
    .getByRole("button", { name: "Добавить выполненный объём" })
    .click();
  await expect(page.getByText("E2E объём")).toBeVisible();
  await expect(page.getByText("Итого: 21 т")).toBeVisible();
  await page.reload();
  await expect(page.getByText("E2E объём")).toBeVisible();
  await page.goto(`${base}/${scenario.ids.blockedWork}`);
  await expect(page.getByText("AREA-B · Зона B")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Добавить выполненный объём" }),
  ).toHaveCount(0);
});
