import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export async function markOwnNotificationRead(notificationId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("mark_own_notification_read", {
    notification_id: notificationId,
  });

  if (error) {
    throw new Error("NOTIFICATION_READ_FAILED");
  }
}

export async function acknowledgeOwnDocumentImpact(notificationId: string) {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("acknowledge_own_document_impact", {
    notification_id: notificationId,
  });

  if (error) {
    throw new Error("ACKNOWLEDGEMENT_FAILED");
  }
}
