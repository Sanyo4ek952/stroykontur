import { beforeEach, describe, expect, it, vi } from "vitest";

const supabaseMocks = vi.hoisted(() => ({
  signInWithPassword: vi.fn(),
}));

vi.mock("@/server/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => ({
    auth: {
      signInWithPassword: supabaseMocks.signInWithPassword,
    },
  })),
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn(),
}));

import { signIn, type SignInState } from "./actions";

const initialSignInState: SignInState = {};

function credentials(email: string, password: string) {
  const formData = new FormData();
  formData.set("email", email);
  formData.set("password", password);

  return formData;
}

describe("signIn", () => {
  beforeEach(() => {
    supabaseMocks.signInWithPassword.mockReset();
  });

  it("rejects invalid form input before calling Supabase", async () => {
    const result = await signIn(
      initialSignInState,
      credentials("not-an-email", ""),
    );

    expect(result.fieldErrors?.email).toContain(
      "Введите корректный адрес электронной почты.",
    );
    expect(result.fieldErrors?.password).toContain("Введите пароль.");
    expect(supabaseMocks.signInWithPassword).not.toHaveBeenCalled();
  });

  it("maps invalid credentials to a stable safe message", async () => {
    supabaseMocks.signInWithPassword.mockResolvedValue({
      error: {
        code: "invalid_credentials",
        message: "raw provider error",
      },
    });

    const result = await signIn(
      initialSignInState,
      credentials("worker@example.test", "wrong-password"),
    );

    expect(result).toEqual({
      message: "Неверная электронная почта или пароль.",
    });
    expect(JSON.stringify(result)).not.toContain("raw provider error");
  });

  it("returns a safe message for an unexpected Auth failure", async () => {
    supabaseMocks.signInWithPassword.mockRejectedValue(
      new Error("connection details"),
    );

    const result = await signIn(
      initialSignInState,
      credentials("worker@example.test", "valid-password"),
    );

    expect(result).toEqual({
      message: "Не удалось войти. Попробуйте ещё раз.",
    });
    expect(JSON.stringify(result)).not.toContain("connection details");
  });
});
