"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import {
  acknowledgeOwnDocumentImpact,
  markOwnNotificationRead,
} from "@/modules/acknowledgements/server/commands";
import { requireUser } from "@/server/auth/require-user";

const notificationSchema = z.object({
  notificationId: z.uuid(),
});

export type DemoActionState = {
  message?: string;
  status?: "error" | "success";
};

async function parseOwnNotification(formData: FormData) {
  await requireUser();
  return notificationSchema.safeParse({
    notificationId: formData.get("notificationId"),
  });
}

export async function markNotificationRead(
  _state: DemoActionState,
  formData: FormData,
): Promise<DemoActionState> {
  const parsed = await parseOwnNotification(formData);
  if (!parsed.success) {
    return { message: "Некорректное уведомление.", status: "error" };
  }

  try {
    await markOwnNotificationRead(parsed.data.notificationId);
    revalidatePath("/app/demo/vertical-slice");
    revalidatePath("/app/projects", "layout");
    return { message: "Уведомление отмечено прочитанным.", status: "success" };
  } catch {
    return {
      message:
        "Не удалось отметить уведомление. Обновите страницу и повторите.",
      status: "error",
    };
  }
}

export async function acknowledgeDocumentImpact(
  _state: DemoActionState,
  formData: FormData,
): Promise<DemoActionState> {
  const parsed = await parseOwnNotification(formData);
  if (!parsed.success) {
    return { message: "Некорректное уведомление.", status: "error" };
  }

  try {
    await acknowledgeOwnDocumentImpact(parsed.data.notificationId);
    revalidatePath("/app/demo/vertical-slice");
    revalidatePath("/app/projects", "layout");
    return { message: "Ознакомление подтверждено.", status: "success" };
  } catch {
    return {
      message:
        "Сначала отметьте уведомление прочитанным, затем повторите подтверждение.",
      status: "error",
    };
  }
}
