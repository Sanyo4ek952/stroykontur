"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import { createServerSupabaseClient } from "@/server/supabase/server";

const signInSchema = z.object({
  email: z
    .string()
    .trim()
    .pipe(z.email({ error: "Введите корректный адрес электронной почты." })),
  password: z.string().min(1, { error: "Введите пароль." }),
});

export type SignInState = {
  fieldErrors?: {
    email?: string[];
    password?: string[];
  };
  message?: string;
};

export async function signIn(
  _previousState: SignInState,
  formData: FormData,
): Promise<SignInState> {
  const parsedCredentials = signInSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!parsedCredentials.success) {
    return {
      fieldErrors: parsedCredentials.error.flatten().fieldErrors,
    };
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { error } = await supabase.auth.signInWithPassword(
      parsedCredentials.data,
    );

    if (error?.code === "invalid_credentials") {
      return { message: "Неверная электронная почта или пароль." };
    }

    if (error) {
      return { message: "Не удалось войти. Попробуйте ещё раз." };
    }
  } catch {
    return { message: "Не удалось войти. Попробуйте ещё раз." };
  }

  redirect("/app");
}
