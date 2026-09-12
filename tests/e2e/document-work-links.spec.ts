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

test("PTO manages a Document ↔ Work link and preserves propagation history", async ({
  page,
  scenario,
}) => {
  const projectId = scenario.ids.project;
  const pto = scenario.demoUser;
  const workManager = scenario.manager;
  const documentId = scenario.ids.technicalDocument;
  const workId = scenario.ids.blockedWork;
  await login(page, pto);
  await page.goto(`/app/projects/${projectId}/documents/${documentId}`);

  const relatedWorks = page
    .getByRole("heading", { name: "Связанные работы" })
    .locator("..");
  await expect(
    relatedWorks.getByText("WORK-FND-001", { exact: true }),
  ).toBeVisible();
  await relatedWorks.getByLabel("Работа").selectOption(workId);
  await expect(
    relatedWorks.getByText(
      "У документа уже есть действующая выдача в производство.",
    ),
  ).toBeVisible();
  await relatedWorks
    .getByLabel("Подтверждаю немедленный запуск цепочки влияния.")
    .check();
  await relatedWorks.getByRole("button", { name: "Связать работу" }).click();
  await expect(
    relatedWorks.getByText("WORK-FND-002", { exact: true }),
  ).toBeVisible();

  await page.reload();
  await expect(page.getByText("WORK-FND-002", { exact: true })).toBeVisible();
  await page.goto(`/app/projects/${projectId}/works/${workId}`);
  await expect(page.getByText("КЖ-01", { exact: true })).toBeVisible();

  await page.goto(`/app/projects/${projectId}/documents/${documentId}`);
  const unlink = relatedWorks
    .getByRole("button", { name: "Убрать связь" })
    .last();
  await unlink.click();
  await relatedWorks
    .getByLabel("Подтверждаю историческое закрытие связи.")
    .last()
    .check();
  await relatedWorks
    .getByRole("button", { name: "Убрать связь" })
    .last()
    .click();
  await expect(
    relatedWorks.getByRole("heading", { name: "История связей" }),
  ).toBeVisible();
  await expect(
    relatedWorks.getByText("WORK-FND-002", { exact: true }),
  ).toBeVisible();

  await page.getByRole("button", { name: "Выйти" }).click();
  await expect(page).toHaveURL(/\/login$/);
  await login(page, workManager);
  await page.goto(`/app/projects/${projectId}/notifications`);
  await expect(page.getByText("WORK-FND-002", { exact: true })).toBeVisible();
});

test("a user without the relationship permission cannot manage Document ↔ Work links", async ({
  page,
  scenario,
}) => {
  const projectId = scenario.ids.project;
  const workManager = scenario.manager;
  const documentId = scenario.ids.technicalDocument;
  await login(page, workManager);
  await page.goto(`/app/projects/${projectId}/documents/${documentId}`);
  await expect(
    page.getByRole("button", { name: "Связать работу" }),
  ).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Убрать связь" })).toHaveCount(
    0,
  );
});
