import { expect, test } from "@playwright/test";

const demoUser = {
  email: "demo@construction.test",
  password: "Demo-Task012-2026!",
};
const projectId = "10120000-0000-0000-0000-000000000001";

test("navigates the application shell and persists READ and ACK", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(demoUser.email);
  await page.getByLabel("Пароль").fill(demoUser.password);
  await page.getByRole("button", { name: "Войти" }).click();

  await expect(page).toHaveURL(/\/app$/);
  await expect(
    page.getByRole("heading", {
      name: "Жилой комплекс Северный квартал",
    }),
  ).toBeVisible();
  await page
    .getByRole("link", { name: /Жилой комплекс Северный квартал/ })
    .click();
  await expect(page).toHaveURL("/app/projects/" + projectId);
  await expect(
    page.getByRole("heading", { name: "Что требует внимания" }),
  ).toBeVisible();

  await page.getByRole("link", { name: "Мои задачи" }).click();
  await expect(page).toHaveURL("/app/projects/" + projectId + "/tasks");
  await expect(
    page.getByRole("heading", { name: "Проверить влияние документа" }),
  ).toBeVisible();
  await expect(page.getByText("WORK-FND-001", { exact: false })).toBeVisible();

  await page.getByRole("link", { name: "Документы" }).click();
  await expect(page).toHaveURL("/app/projects/" + projectId + "/documents");
  await expect(page.getByText("КЖ-01", { exact: true })).toBeVisible();
  await expect(page.getByText("R2", { exact: true })).toBeVisible();

  await page.getByRole("link", { name: "Работы" }).click();
  await expect(page).toHaveURL("/app/projects/" + projectId + "/works");
  await expect(page.getByText("WORK-FND-001", { exact: true })).toBeVisible();

  await page.getByRole("link", { name: "Уведомления" }).click();
  await expect(page).toHaveURL("/app/projects/" + projectId + "/notifications");
  await expect(
    page.getByText("Новое уведомление", { exact: true }),
  ).toBeVisible();

  await page.getByRole("button", { name: "Отметить прочитанным" }).click();
  await expect(
    page.getByRole("button", { name: "Подтвердить ознакомление" }),
  ).toBeVisible();

  await page.getByRole("button", { name: "Подтвердить ознакомление" }).click();
  await expect(
    page.getByText("Ознакомление подтверждено", { exact: true }),
  ).toBeVisible();

  await page.reload();
  await expect(
    page.getByText("Ознакомление подтверждено", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Отметить прочитанным" }),
  ).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Подтвердить ознакомление" }),
  ).toHaveCount(0);

  await page.goto("/app/demo/vertical-slice");
  await expect(
    page.getByRole("heading", {
      name: "Изменение документации → ознакомление",
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Ознакомление подтверждено" }),
  ).toBeVisible();
});

test("does not expose an unrelated project URL", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(demoUser.email);
  await page.getByLabel("Пароль").fill(demoUser.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);

  await page.goto(
    "/app/projects/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/documents",
  );
  await expect(
    page.getByRole("heading", { name: "Проект не найден" }),
  ).toBeVisible();
  await expect(page.getByText("КЖ-01", { exact: true })).toHaveCount(0);
});

test("keeps project navigation usable on a phone viewport", async ({
  page,
}) => {
  await page.setViewportSize({ height: 844, width: 390 });
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(demoUser.email);
  await page.getByLabel("Пароль").fill(demoUser.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);

  await page
    .getByRole("link", { name: /Жилой комплекс Северный квартал/ })
    .click();
  const navigation = page.getByRole("navigation", {
    name: "Разделы проекта",
  });
  await expect(navigation.getByRole("link", { name: "Обзор" })).toBeVisible();
  await expect(
    navigation.getByRole("link", { name: "Уведомления" }),
  ).toBeVisible();

  await navigation.getByRole("link", { name: "Работы" }).click();
  await expect(page.getByRole("heading", { name: "Работы" })).toBeVisible();
  await expect(page.getByText("WORK-FND-001", { exact: true })).toBeVisible();
});
