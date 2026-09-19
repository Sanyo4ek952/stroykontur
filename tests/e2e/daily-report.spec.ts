import { createClient } from "@supabase/supabase-js";
import type { Page } from "@playwright/test";
import { expect, test, type Credentials } from "./fixtures";

test("concurrent report retries and competing decisions leave one whole-report result", async ({
  scenario,
}) => {
  test.setTimeout(90_000);
  const reporter = await clientFor(scenario.field);
  const confirmer = await clientFor(scenario.siteManager);
  const make = async () => {
    const args = {
      p_project_area_id: scenario.ids.areaA,
      p_report_date: "2026-09-13",
      p_workers_count: 1,
      p_summary: "concurrent",
      p_problems: "",
      p_command_id: crypto.randomUUID(),
    };
    const created = await Promise.all([
      reporter.rpc("create_daily_report", args),
      reporter.rpc("create_daily_report", args),
    ]);
    created.forEach((result) => expect(result.error).toBeNull());
    expect(created[0].data).toBe(created[1].data);
    const id = created[0].data as string;
    const progress = {
      p_daily_report_id: id,
      p_work_id: scenario.ids.work,
      p_quantity: 2.5,
      p_note: "concurrent",
      p_command_id: crypto.randomUUID(),
    };
    const added = await Promise.all([
      reporter.rpc("add_daily_report_progress", progress),
      reporter.rpc("add_daily_report_progress", progress),
    ]);
    added.forEach((result) => expect(result.error).toBeNull());
    expect(added[0].data).toBe(added[1].data);
    expect(
      (
        await reporter.rpc("add_daily_report_progress", {
          ...progress,
          p_work_id: scenario.ids.dailyReportWork,
          p_quantity: 1,
          p_command_id: crypto.randomUUID(),
        })
      ).error,
    ).toBeNull();
    const submit = { p_daily_report_id: id, p_command_id: crypto.randomUUID() };
    const submitted = await Promise.all([
      reporter.rpc("submit_daily_report", submit),
      reporter.rpc("submit_daily_report", submit),
    ]);
    submitted.forEach((result) => expect(result.error).toBeNull());
    return id;
  };
  const id = await make();
  const args = { p_daily_report_id: id, p_command_id: crypto.randomUUID() };
  const results = await Promise.all([
    confirmer.rpc("confirm_daily_report", args),
    confirmer.rpc("confirm_daily_report", args),
  ]);
  results.forEach((result) => expect(result.error).toBeNull());
  const children = await reporter
    .from("work_progress_entries")
    .select("confirmation_status")
    .eq("daily_report_id", id);
  expect(children.error).toBeNull();
  expect(children.data).toEqual([
    { confirmation_status: "CONFIRMED" },
    { confirmation_status: "CONFIRMED" },
  ]);
  const competingId = await make();
  const competing = await Promise.all([
    confirmer.rpc("confirm_daily_report", {
      p_daily_report_id: competingId,
      p_command_id: crypto.randomUUID(),
    }),
    confirmer.rpc("return_daily_report", {
      p_daily_report_id: competingId,
      p_return_reason: "competing decision",
      p_command_id: crypto.randomUUID(),
    }),
  ]);
  expect(competing.filter((result) => !result.error)).toHaveLength(1);
  expect(competing.find((result) => result.error)?.error?.code).toBe("DR003");
  const report = await reporter
    .from("daily_reports")
    .select("status")
    .eq("id", competingId)
    .single();
  expect(report.error).toBeNull();
  const final = await reporter
    .from("work_progress_entries")
    .select("confirmation_status")
    .eq("daily_report_id", competingId);
  expect(final.error).toBeNull();
  expect(final.data).toHaveLength(2);
  expect(
    final.data!.every((row) => row.confirmation_status === report.data!.status),
  ).toBe(true);
});

async function login(page: Page, credentials: Credentials) {
  await page.goto("/login");
  await page.getByLabel("Электронная почта").fill(credentials.email);
  await page.getByLabel("Пароль").fill(credentials.password);
  await page.getByRole("button", { name: "Войти", exact: true }).click();
  await page.waitForURL(/\/app$/, { timeout: 30_000 });
}
async function clientFor(credentials: Credentials) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  if (!["127.0.0.1", "localhost"].includes(new URL(url).hostname))
    throw new Error("Local Supabase only.");
  const client = createClient(
    url,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error } = await client.auth.signInWithPassword(credentials);
  expect(error).toBeNull();
  return client;
}
async function createReport(
  page: Page,
  projectId: string,
  areaId: string,
  works: string[],
) {
  await page.goto(`/app/projects/${projectId}/daily-reports`);
  await page.getByRole("link", { name: "Создать отчёт", exact: true }).click();
  await page
    .getByRole("combobox", { name: "Зона", exact: true })
    .selectOption(areaId);
  await page.getByLabel("Дата отчёта").fill("2026-09-13");
  await page.getByLabel("Количество работников").fill("5");
  await page.getByLabel("Выполненные работы").fill("DailyReport E2E");
  await page
    .getByLabel("Проблемы", { exact: true })
    .fill("Нет доступа к части площадки");
  await page
    .getByRole("button", { name: "Создать отчёт", exact: true })
    .click();
  // The create action redirects; wait for navigation before inspecting the
  // detail page (its first dev compilation can exceed the assertion timeout).
  await page.waitForURL(
    (url) =>
      url.pathname.startsWith(`/app/projects/${projectId}/daily-reports/`) &&
      /[0-9a-f-]{36}$/.test(url.pathname),
    { timeout: 30_000 },
  );
  await expect(page.getByTestId("report-status")).toHaveText("DRAFT");
  await page.getByLabel("Количество работников").fill("7");
  await page.getByRole("button", { name: "Сохранить черновик" }).click();
  await expect(page.locator("dd").filter({ hasText: /^7$/ })).toBeVisible();
  for (const [index, work] of works.entries()) {
    await page
      .getByRole("combobox", { name: "Работа", exact: true })
      .selectOption(work);
    await page
      .getByLabel("Выполненный объём", { exact: true })
      .fill(index === 0 ? "2.5" : "1.0");
    await page.getByLabel("Примечание").fill("DailyReport progress " + index);
    await page
      .getByRole("button", { name: "Добавить объём", exact: true })
      .click();
    await expect(page.getByTestId("report-progress")).toHaveCount(index + 1);
  }
  await expect(
    page
      .getByTestId("report-progress")
      .getByText("Ожидает подтверждения", { exact: true }),
  ).toHaveCount(works.length);
  const url = page.url();
  await page
    .getByRole("button", { name: "Отправить на подтверждение" })
    .click();
  await expect(page.getByTestId("report-status")).toHaveText("SUBMITTED");
  await expect(
    page.getByRole("button", { name: "Сохранить черновик" }),
  ).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Добавить объём", exact: true }),
  ).toHaveCount(0);
  return { url, id: url.split("/").at(-1)! };
}
async function fact(
  client: Awaited<ReturnType<typeof clientFor>>,
  workId: string,
) {
  const { data, error } = await client
    .from("work_progress_entries")
    .select("quantity")
    .eq("work_id", workId)
    .eq("confirmation_status", "CONFIRMED");
  expect(error).toBeNull();
  return data!.reduce((total, row) => total + Number(row.quantity), 0);
}
test("DailyReport confirms both Works atomically and persists confirmed totals", async ({
  page,
  browser,
  scenario,
}) => {
  test.setTimeout(120_000);
  const master = await clientFor(scenario.field);
  const before1 = await fact(master, scenario.ids.work);
  const before2 = await fact(master, scenario.ids.dailyReportWork);
  await login(page, scenario.field);
  const report = await createReport(
    page,
    scenario.ids.project,
    scenario.ids.areaA,
    [scenario.ids.work, scenario.ids.dailyReportWork],
  );
  expect(await fact(master, scenario.ids.work)).toBe(before1);
  expect(await fact(master, scenario.ids.dailyReportWork)).toBe(before2);
  const context = await browser.newContext();
  try {
    const managerPage = await context.newPage();
    await login(managerPage, scenario.siteManager);
    await managerPage.goto(report.url);
    const commandId = await managerPage
      .locator("form")
      .filter({
        has: managerPage.getByRole("button", {
          name: "Подтвердить отчёт",
          exact: true,
        }),
      })
      .locator('input[name="commandId"]')
      .inputValue();
    await managerPage
      .getByRole("button", { name: "Подтвердить отчёт", exact: true })
      .click();
    await expect(managerPage.getByTestId("report-status")).toHaveText(
      "CONFIRMED",
    );
    await expect(
      managerPage
        .getByTestId("report-progress")
        .getByText("Подтверждено", { exact: true }),
    ).toHaveCount(2);
    const manager = await clientFor(scenario.siteManager);
    expect(
      (
        await manager.rpc("confirm_daily_report", {
          p_daily_report_id: report.id,
          p_command_id: commandId,
        })
      ).error,
    ).toBeNull();
    expect(await fact(master, scenario.ids.work)).toBe(before1 + 2.5);
    expect(await fact(master, scenario.ids.dailyReportWork)).toBe(before2 + 1);
    await managerPage.reload();
    await expect(managerPage.getByTestId("report-status")).toHaveText(
      "CONFIRMED",
    );
    await expect(
      managerPage
        .getByTestId("report-progress")
        .getByText("Подтверждено", { exact: true }),
    ).toHaveCount(2);
    await managerPage.goto(
      `/app/projects/${scenario.ids.project}/works/${scenario.ids.work}`,
    );
    await expect(
      managerPage.getByText(`Итого выполнено: ${before1 + 2.5} т`, {
        exact: true,
      }),
    ).toBeVisible();
    await expect(
      managerPage.getByRole("link", {
        name: "Дневной отчёт — решение по всему отчёту",
      }),
    ).toBeVisible();
  } finally {
    await context.close();
  }
});
test("DailyReport return preserves reason and leaves confirmed totals unchanged", async ({
  page,
  browser,
  scenario,
}) => {
  test.setTimeout(120_000);
  const master = await clientFor(scenario.field);
  const before = await fact(master, scenario.ids.work);
  await login(page, scenario.field);
  const report = await createReport(
    page,
    scenario.ids.project,
    scenario.ids.areaA,
    [scenario.ids.work],
  );
  const context = await browser.newContext();
  try {
    const managerPage = await context.newPage();
    await login(managerPage, scenario.siteManager);
    await managerPage.goto(report.url);
    await managerPage
      .getByLabel("Причина возврата", { exact: true })
      .fill("Проверить фактический объём");
    await managerPage
      .getByRole("button", { name: "Вернуть отчёт", exact: true })
      .click();
    await expect(managerPage.getByTestId("report-status")).toHaveText(
      "RETURNED",
    );
    await expect(
      managerPage
        .getByTestId("report-progress")
        .getByText("Возвращено: Проверить фактический объём", { exact: true }),
    ).toBeVisible();
    expect(await fact(master, scenario.ids.work)).toBe(before);
    await managerPage.reload();
    await expect(
      managerPage.getByText("Причина возврата: Проверить фактический объём", {
        exact: true,
      }),
    ).toBeVisible();
    await page.reload();
    await expect(page.getByTestId("report-status")).toHaveText("RETURNED");
    await expect(
      page.getByRole("button", { name: "Сохранить черновик" }),
    ).toHaveCount(0);
    await expect(
      page.getByRole("button", { name: "Добавить объём", exact: true }),
    ).toHaveCount(0);
  } finally {
    await context.close();
  }
});
test("Area B confirmer has no Area A controls and both database decisions are denied", async ({
  page,
  browser,
  scenario,
}) => {
  test.setTimeout(120_000);
  await login(page, scenario.field);
  const report = await createReport(
    page,
    scenario.ids.project,
    scenario.ids.areaA,
    [scenario.ids.work],
  );
  const context = await browser.newContext();
  try {
    const otherPage = await context.newPage();
    await login(otherPage, scenario.areaBConfirmer);
    await otherPage.goto(report.url);
    await expect(
      otherPage.getByText("Отчёт не найден или недоступен.", { exact: true }),
    ).toBeVisible();
    await expect(
      otherPage.getByRole("button", { name: "Подтвердить отчёт", exact: true }),
    ).toHaveCount(0);
    await expect(
      otherPage.getByRole("button", { name: "Вернуть отчёт", exact: true }),
    ).toHaveCount(0);
    const other = await clientFor(scenario.areaBConfirmer);
    const confirm = await other.rpc("confirm_daily_report", {
      p_daily_report_id: report.id,
      p_command_id: crypto.randomUUID(),
    });
    const returned = await other.rpc("return_daily_report", {
      p_daily_report_id: report.id,
      p_return_reason: "чужая зона",
      p_command_id: crypto.randomUUID(),
    });
    expect(confirm.error?.code).toBe("42501");
    expect(returned.error?.code).toBe("42501");
    await page.reload();
    await expect(page.getByTestId("report-status")).toHaveText("SUBMITTED");
  } finally {
    await context.close();
  }
});
