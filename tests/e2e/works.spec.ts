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

test("shows searchable read-only Work details for the demo PTO user", async ({
  page,
  scenario,
}) => {
  const demoUser = scenario.demoUser;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  await login(page, demoUser);
  await page.goto(`${worksPath}?search=Армирование&status=READY`);

  const seededWork = page
    .getByRole("listitem")
    .filter({ hasText: "WORK-FND-001" });
  await expect(seededWork).toContainText("120 т");
  await expect(seededWork).toContainText("Вы");
  await expect(page.getByRole("link", { name: "Создать работу" })).toHaveCount(
    0,
  );

  await seededWork.getByRole("link", { name: /Армирование/ }).click();
  await expect(
    page.getByRole("heading", { name: /Армирование/ }),
  ).toBeVisible();
  await expect(
    page.getByText("Подготовка основания фундаментной плиты"),
  ).toBeVisible();
  await expect(
    page.getByText("Бетонирование фундаментной плиты секции 1"),
  ).toBeVisible();
  await expect(
    page
      .getByRole("listitem")
      .filter({ hasText: "Смонтирован первый участок армирования." })
      .getByText("18.5 т", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Смонтирован первый участок армирования."),
  ).toBeVisible();
  await expect(
    page.getByText("Текущее назначение", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", {
      name: /назначить|сменить|начать|завершить|закрыть|пауза|зависимост|прогресс/i,
    }),
  ).toHaveCount(0);

  await page.goto(`${worksPath}?search=не-существует`);
  await expect(
    page.getByRole("heading", { name: "Работы не найдены." }),
  ).toBeVisible();
  await page.goto(`${worksPath}/new`);
  await expect(
    page.getByText("Недостаточно прав для создания работы."),
  ).toBeVisible();
});

test("creates a PLANNED Work through an existing project-scoped grant", async ({
  page,
  scenario,
}) => {
  const workCreator = scenario.manager;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  await login(page, workCreator);
  await page.goto(`${worksPath}/new`);

  await page.getByLabel("Код работы").fill("WORK-FND-001");
  await page.getByLabel("Название").fill("Дубликат");
  await page.getByRole("button", { name: "Создать работу" }).click();
  await expect(
    page.getByText("Работа с таким кодом уже существует."),
  ).toBeVisible();

  await page.getByLabel("Код работы").fill("E2E-TASK-015");
  await page.getByLabel("Название").fill("Работа для проверки TASK-015");
  await page.getByLabel("Плановый объём").fill("25.5");
  await page.getByLabel("Единица измерения").fill("м³");
  await page.getByLabel("Плановый старт").fill("2026-09-05");
  await page.getByLabel("Плановый финиш").fill("2026-09-15");
  await page.getByRole("button", { name: "Создать работу" }).click();

  await expect(page).toHaveURL(new RegExp(`${worksPath}/[0-9a-f-]+$`));
  await expect(
    page.getByRole("heading", { name: "Работа для проверки TASK-015" }),
  ).toBeVisible();
  await expect(page.getByText("Запланирована", { exact: true })).toBeVisible();
  await expect(
    page
      .getByRole("heading", { name: "Работа", exact: true })
      .locator("..")
      .getByText("25.5 м³", { exact: true }),
  ).toBeVisible();
  await page.reload();
  await expect(
    page.getByRole("heading", { name: "Работа для проверки TASK-015" }),
  ).toBeVisible();
});

test("does not expose a random or cross-project Work URL", async ({
  page,
  scenario,
}) => {
  const demoUser = scenario.demoUser;
  const seededWorkId = scenario.ids.work;
  const worksPath = `/app/projects/${scenario.ids.project}/works`;
  await login(page, demoUser);
  await page.goto(`${worksPath}/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`);
  await expect(
    page.getByRole("heading", { name: "Работа не найдена." }),
  ).toBeVisible();
  await expect(page.getByText("WORK-FND-001", { exact: true })).toHaveCount(0);

  await page.goto(
    `/app/projects/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/works/${seededWorkId}`,
  );
  await expect(
    page.getByRole("heading", { name: "Проект не найден" }),
  ).toBeVisible();
  await expect(page.getByText("WORK-FND-001", { exact: true })).toHaveCount(0);
});
