import "server-only";

import { createServerSupabaseClient } from "@/server/supabase/server";

export async function getOwnVerticalSlice() {
  const supabase = await createServerSupabaseClient();
  const { data: notifications, error: notificationError } = await supabase
    .from("notifications")
    .select("id")
    .order("created_at", { ascending: false })
    .limit(1);

  if (notificationError) {
    throw new Error("Не удалось загрузить уведомление демо-сценария.");
  }

  const notification = notifications[0];
  if (!notification) {
    return null;
  }

  const [
    { data: slice, error: sliceError },
    { data: history, error: historyError },
  ] = await Promise.all([
    supabase.rpc("get_own_vertical_slice", {
      notification_id: notification.id,
    }),
    supabase.rpc("get_own_vertical_slice_audit", {
      notification_id: notification.id,
    }),
  ]);

  if (sliceError || historyError) {
    throw new Error("Не удалось загрузить вертикальный срез.");
  }

  const scenario = slice[0];
  return scenario
    ? { history, notificationId: notification.id, scenario }
    : null;
}
