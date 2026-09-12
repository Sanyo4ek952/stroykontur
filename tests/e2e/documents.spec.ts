import { expect, test, type Credentials } from "./fixtures";

async function login(
  page: import("@playwright/test").Page,
  demoUser: Credentials,
) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(demoUser.email);
  await page.getByLabel("Пароль").fill(demoUser.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
}

test("creates a document and DRAFT revision with safe duplicate errors", async ({
  page,
  scenario,
}) => {
  const demoUser = scenario.demoUser;
  const documentsPath = `/app/projects/${scenario.ids.project}/documents`;
  await login(page, demoUser);
  await page.goto(documentsPath);

  const seededDocument = page
    .getByRole("listitem")
    .filter({ hasText: "КЖ-01" });
  await seededDocument.getByRole("link").click();
  const issueHistory = page
    .getByRole("heading", { name: "История выдачи в производство" })
    .locator("..");
  await expect(issueHistory).toBeVisible();
  await expect(
    issueHistory.getByText("Ревизия R2", { exact: true }),
  ).toBeVisible();
  await expect(
    issueHistory.getByText("Действует", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /выдать|отозвать/i }),
  ).toHaveCount(0);

  await page.goto(`${documentsPath}/new`);
  await page.getByLabel("Код документа").fill("КЖ-01");
  await page.getByLabel("Название").fill("Дубликат");
  await page.getByRole("button", { name: "Создать документ" }).click();
  await expect(
    page.getByText("Документ с таким кодом уже существует.", { exact: true }),
  ).toBeVisible();

  await page.getByLabel("Код документа").fill("E2E-TASK-014");
  await page.getByLabel("Название").fill("Документ для проверки TASK-014");
  await page.getByRole("button", { name: "Создать документ" }).click();
  await expect(page).toHaveURL(new RegExp(`${documentsPath}/[0-9a-f-]+$`));
  await expect(
    page.getByRole("heading", { name: "Документ для проверки TASK-014" }),
  ).toBeVisible();

  await page.getByRole("link", { name: "Создать ревизию" }).click();
  await page.getByLabel("Код ревизии").fill("R1");
  await page.getByRole("button", { name: "Создать ревизию" }).click();
  await expect(page.getByText("Ревизия R1", { exact: true })).toBeVisible();
  await expect(page.getByText("Черновик", { exact: true })).toBeVisible();

  await page.getByRole("link", { name: "Создать ревизию" }).click();
  await page.getByLabel("Код ревизии").fill("R1");
  await page.getByRole("button", { name: "Создать ревизию" }).click();
  await expect(
    page.getByText("Ревизия с таким кодом уже существует.", { exact: true }),
  ).toBeVisible();

  await page.reload();
  await expect(
    page.getByText("Ревизия с таким кодом уже существует.", { exact: true }),
  ).toHaveCount(0);
  await page.getByRole("link", { name: "Отмена" }).click();
  await expect(page.getByText("Ревизия R1", { exact: true })).toBeVisible();

  await page.goto(`${documentsPath}?search=E2E-TASK-014&status=draft`);
  await expect(page.getByText("E2E-TASK-014", { exact: true })).toBeVisible();
  await page.goto(`${documentsPath}?search=не-существует`);
  await expect(
    page.getByRole("heading", { name: "Документы не найдены." }),
  ).toBeVisible();
});

test("does not expose a random or cross-project document URL", async ({
  page,
  scenario,
}) => {
  const demoUser = scenario.demoUser;
  const documentsPath = `/app/projects/${scenario.ids.project}/documents`;
  await login(page, demoUser);
  await page.goto(`${documentsPath}/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`);
  await expect(
    page.getByRole("heading", { name: "Документ не найден." }),
  ).toBeVisible();
  await expect(page.getByText("КЖ-01", { exact: true })).toHaveCount(0);
});
