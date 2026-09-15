import type { Page } from "@playwright/test";

import { expect, test, type Credentials } from "./fixtures";

async function login(page: Page, credentials: Credentials) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}

test("Area requester and construction control complete positive quality acceptance", async ({
  browser,
  page,
  scenario,
}) => {
  test.setTimeout(90_000);
  const path = `/app/projects/${scenario.ids.project}/works/${scenario.ids.qualityWork}`;

  await login(page, scenario.areaBConfirmer);
  await page.goto(path);
  await expect(
    page.getByRole("button", { name: "Вызвать строительный контроль" }),
  ).toHaveCount(0);

  const requesterContext = await browser.newContext();
  const requesterPage = await requesterContext.newPage();
  await login(requesterPage, scenario.siteManager);
  await requesterPage.goto(path);
  await expect(
    requesterPage.getByRole("button", {
      name: "Вызвать строительный контроль",
    }),
  ).toBeVisible();
  await requesterPage
    .getByRole("button", { name: "Вызвать строительный контроль" })
    .click();
  await expect(
    requesterPage.getByText("Вызов создан", { exact: true }),
  ).toBeVisible();
  await requesterPage.reload();
  await expect(
    requesterPage.getByText("Вызов создан", { exact: true }),
  ).toBeVisible();
  await requesterContext.close();

  const qualityContext = await browser.newContext();
  const qualityPage = await qualityContext.newPage();
  await login(qualityPage, scenario.quality);
  await qualityPage.goto(path);
  await expect(
    qualityPage.getByRole("button", { name: "Принять работу" }),
  ).toHaveCount(0);
  await qualityPage.getByRole("button", { name: "Принять вызов" }).click();
  await expect(
    qualityPage.getByText("Проверка запланирована", { exact: true }),
  ).toBeVisible();
  await qualityPage.getByRole("button", { name: "Начать проверку" }).click();
  await expect(
    qualityPage.getByText("Проверка идёт", { exact: true }),
  ).toBeVisible();
  await qualityPage
    .getByLabel("Результат проверки")
    .fill("Работы выполнены по действующей РД, замечаний нет.");
  await qualityPage
    .getByRole("button", { name: "Принять качество работы" })
    .click();
  await expect(
    qualityPage.getByText("Качество принято", { exact: true }),
  ).toBeVisible();
  await expect(
    qualityPage.getByText(
      "Результат: Работы выполнены по действующей РД, замечаний нет.",
    ),
  ).toBeVisible();
  await expect(
    qualityPage.getByText("Принята", { exact: true }).first(),
  ).toBeVisible();
  await qualityPage.reload();
  await expect(
    qualityPage.getByText("Качество принято", { exact: true }),
  ).toBeVisible();
  await expect(
    qualityPage.getByText("Принята", { exact: true }).first(),
  ).toBeVisible();
  await qualityContext.close();
});
