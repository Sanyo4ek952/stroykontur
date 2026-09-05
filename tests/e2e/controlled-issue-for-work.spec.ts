import { expect, test } from "@playwright/test";

const issuer = {
  email: "demo@construction.test",
  password: "Demo-Task012-2026!",
};
const recipient = {
  email: "work.manager@construction.test",
  password: "Work-Task015-2026!",
};
const projectId = "10120000-0000-0000-0000-000000000001";
const documentId = "50120000-0000-0000-0000-000000000017";

test("approved revision issues for work and propagates to the linked Work", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(issuer.email);
  await page.getByLabel("Пароль").fill(issuer.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);

  await page.goto(`/app/projects/${projectId}/documents/${documentId}`);
  const currentIssue = page
    .getByRole("heading", { name: "Текущая производственная ревизия" })
    .locator("..");
  await expect(
    currentIssue.getByText("Документ ещё не выдавался в производство.", {
      exact: true,
    }),
  ).toBeVisible();

  page.once("dialog", async (dialog) => {
    expect(dialog.message()).toContain("Выдать ревизию R1 в производство?");
    await dialog.accept();
  });
  await page.getByRole("button", { name: "Выдать в производство" }).click();

  await expect(currentIssue.getByText(/Ревизия R1, выдана/)).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Выдать в производство" }),
  ).toHaveCount(0);

  await page.getByRole("button", { name: "Выйти" }).click();
  await page.getByLabel("Электронная почта").fill(recipient.email);
  await page.getByLabel("Пароль").fill(recipient.password);
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page).toHaveURL(/\/app$/);
  await page.goto(`/app/projects/${projectId}/notifications`);
  await expect(page.getByText("WORK-017-E2E", { exact: true })).toBeVisible();
});
