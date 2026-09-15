import { z } from "zod";

export const inspectionResultSchema = z.object({
  resultNote: z
    .string()
    .trim()
    .min(1, "Укажите результат проверки.")
    .max(2000, "Результат проверки должен быть не длиннее 2000 символов."),
});
