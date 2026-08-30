import { createBrowserClient } from "@supabase/ssr";

import type { Database } from "@/server/supabase/database.types";
import { publicEnvironment } from "@/shared/config/public-env";

export function createBrowserSupabaseClient() {
  return createBrowserClient<Database>(
    publicEnvironment.NEXT_PUBLIC_SUPABASE_URL,
    publicEnvironment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}
