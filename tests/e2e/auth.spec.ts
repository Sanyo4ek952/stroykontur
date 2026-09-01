import { createClient } from "@supabase/supabase-js";
import { expect, test } from "@playwright/test";

const testUser = {
  email: "task-003-auth-e2e@example.test",
  password: "local-task-003-password",
};

function getLocalSupabaseEnvironment() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !publishableKey) {
    throw new Error(
      "Local Supabase URL and publishable key are required for Auth E2E.",
    );
  }

  const hostname = new URL(url).hostname;

  if (hostname !== "127.0.0.1" && hostname !== "localhost") {
    throw new Error("Auth E2E refuses to use a non-local Supabase project.");
  }

  return { publishableKey, url };
}

test.beforeAll(async () => {
  const { publishableKey, url } = getLocalSupabaseEnvironment();
  const supabase = createClient(url, publishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });

  const { error: signUpError } = await supabase.auth.signUp(testUser);

  if (signUpError && signUpError.code !== "user_already_exists") {
    throw new Error(
      `Unable to prepare the local Auth test user: ${signUpError.code}`,
    );
  }

  const { error: signInError } =
    await supabase.auth.signInWithPassword(testUser);

  if (signInError) {
    throw new Error(
      `Unable to verify the local Auth test user: ${signInError.code}`,
    );
  }

  await supabase.auth.signOut({ scope: "local" });
});

test("protects the authenticated application boundary", async ({ page }) => {
  await page.goto("/app");

  await expect(page).toHaveURL(/\/login$/);

  await page.getByLabel("Электронная почта").fill(testUser.email);
  await page.getByLabel("Пароль").fill(testUser.password);
  await page.getByRole("button", { name: "Войти" }).click();

  await expect(page).toHaveURL(/\/app$/);
  await expect(page.getByRole("heading", { name: "Проекты" })).toBeVisible();
  await expect(page.getByText(testUser.email)).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Нет доступных проектов" }),
  ).toBeVisible();

  await page.getByRole("button", { name: "Выйти" }).click();

  await expect(page).toHaveURL(/\/login$/);

  await page.goto("/app");
  await expect(page).toHaveURL(/\/login$/);
});
