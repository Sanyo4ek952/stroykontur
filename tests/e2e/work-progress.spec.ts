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

async function signOut(page: import("@playwright/test").Page) {
  await page.getByRole("button", { name: "Выйти" }).click();
  await expect(page).toHaveURL(/\/login$/);
}

test("master report is confirmed by the same-Area site manager and persists", async ({
  page,
  scenario,
}) => {
  const base = `/app/projects/${scenario.ids.project}/works`;
  test.setTimeout(90_000);

  await login(page, scenario.field);
  await page.goto(`${base}/${scenario.ids.work}`);
  await expect(page.getByText("AREA-A · Зона A")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Добавить выполненный объём" }),
  ).toBeVisible();
  await expect(
    page.getByText("Итого выполнено: 0 т", { exact: true }),
  ).toBeVisible();
  await page.getByLabel("Выполненный объём").fill("2.5");
  await page.getByLabel("Примечание").fill("E2E подтверждение");
  await page
    .getByRole("button", { name: "Добавить выполненный объём" })
    .click();

  const entry = page.locator("li").filter({ hasText: "E2E подтверждение" });
  await expect(
    entry.getByText("Ожидает подтверждения", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Итого выполнено: 0 т", { exact: true }),
  ).toBeVisible();

  await expect(entry.getByRole("button", { name: "Подтвердить" })).toHaveCount(
    0,
  );
  await expect(entry.getByRole("button", { name: "Вернуть" })).toHaveCount(0);

  await signOut(page);
  await login(page, scenario.siteManager);
  await page.goto(`${base}/${scenario.ids.work}`);
  const pendingEntry = page
    .locator("li")
    .filter({ hasText: "E2E подтверждение" });
  await expect(
    pendingEntry.getByRole("button", { name: "Подтвердить" }),
  ).toBeVisible();
  await pendingEntry.getByRole("button", { name: "Подтвердить" }).click();
  await expect(
    page.getByText("Итого выполнено: 2.5 т", { exact: true }),
  ).toBeVisible();
  await expect(
    pendingEntry.getByText("Подтверждено", { exact: true }),
  ).toBeVisible();
  await page.reload();
  await expect(
    page.getByText("Итого выполнено: 2.5 т", { exact: true }),
  ).toBeVisible();
  await expect(
    page
      .locator("li")
      .filter({ hasText: "E2E подтверждение" })
      .getByText("Подтверждено", { exact: true }),
  ).toBeVisible();

  await page.goto(`${base}/${scenario.ids.blockedWork}`);
  await expect(page.getByRole("button", { name: "Подтвердить" })).toHaveCount(
    0,
  );
  await expect(page.getByRole("button", { name: "Вернуть" })).toHaveCount(0);
});

test("returned progress stays in history and does not change the confirmed total", async ({
  page,
  scenario,
}) => {
  const base = `/app/projects/${scenario.ids.project}/works`;
  test.setTimeout(90_000);

  await login(page, scenario.field);
  await page.goto(`${base}/${scenario.ids.work}`);
  await page.getByLabel("Выполненный объём").fill("1");
  await page.getByLabel("Примечание").fill("E2E возврат");
  await page
    .getByRole("button", { name: "Добавить выполненный объём" })
    .click();
  await expect(
    page.getByText("Итого выполнено: 0 т", { exact: true }),
  ).toBeVisible();

  await expect(
    page
      .getByRole("listitem")
      .filter({ hasText: "E2E возврат" })
      .getByText("Ожидает подтверждения", { exact: true }),
  ).toBeVisible();

  await signOut(page);
  await login(page, scenario.siteManager);
  await page.goto(`${base}/${scenario.ids.work}`);
  const entry = page.locator("li").filter({ hasText: "E2E возврат" });
  await entry.getByRole("button", { name: "Вернуть" }).click();
  await entry.getByLabel("Причина возврата").fill("Неверный объём");
  await entry.getByRole("button", { name: "Вернуть запись" }).click();
  await expect(
    entry.getByText("Возвращено: Неверный объём", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Итого выполнено: 0 т", { exact: true }),
  ).toBeVisible();

  await signOut(page);
  await login(page, scenario.field);
  await page.goto(`${base}/${scenario.ids.work}`);
  await expect(
    page
      .locator("li")
      .filter({ hasText: "E2E возврат" })
      .getByText("Возвращено: Неверный объём", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Итого выполнено: 0 т", { exact: true }),
  ).toBeVisible();
});
