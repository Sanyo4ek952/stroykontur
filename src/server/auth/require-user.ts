import "server-only";

import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/server/supabase/server";

export type AuthenticatedUser = {
  id: string;
  email?: string;
};

export async function requireUser(): Promise<AuthenticatedUser> {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims) {
    redirect("/login");
  }

  return {
    id: data.claims.sub,
    ...(typeof data.claims.email === "string"
      ? { email: data.claims.email }
      : {}),
  };
}
