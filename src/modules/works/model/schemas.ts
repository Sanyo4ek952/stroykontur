import { z } from "zod";

export const postgresUuidSchema = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

export const workStatuses = [
  "PLANNED",
  "READY",
  "IN_PROGRESS",
  "READY_FOR_INSPECTION",
  "ACCEPTED",
  "CLOSED",
  "BLOCKED",
  "PAUSED",
  "REWORK_REQUIRED",
  "CANCELLED",
] as const;

const emptyToUndefined = (value: unknown) =>
  value === null || (typeof value === "string" && value.trim() === "")
    ? undefined
    : value;

const optionalText = z.preprocess(
  emptyToUndefined,
  z.string().trim().min(1).optional(),
);
const optionalDate = z.preprocess(emptyToUndefined, z.iso.date().optional());
const optionalPositiveNumber = z.preprocess(
  emptyToUndefined,
  z.coerce
    .number({ error: "Введите плановый объём числом." })
    .positive({ error: "Плановый объём должен быть больше нуля." })
    .optional(),
);

export const workSchema = z
  .object({
    code: z.string().trim().min(1, { error: "Введите код работы." }),
    plannedFinishDate: optionalDate,
    plannedQuantity: optionalPositiveNumber,
    plannedStartDate: optionalDate,
    title: z.string().trim().min(1, { error: "Введите название работы." }),
    unit: optionalText,
  })
  .superRefine((value, context) => {
    if ((value.plannedQuantity === undefined) !== (value.unit === undefined)) {
      const message =
        "Плановый объём и единицу измерения нужно указать вместе.";
      context.addIssue({ code: "custom", message, path: ["plannedQuantity"] });
      context.addIssue({ code: "custom", message, path: ["unit"] });
    }

    if (
      value.plannedStartDate &&
      value.plannedFinishDate &&
      value.plannedFinishDate < value.plannedStartDate
    ) {
      context.addIssue({
        code: "custom",
        message: "Дата окончания не может быть раньше даты начала.",
        path: ["plannedFinishDate"],
      });
    }
  })
  .transform((value) => ({
    ...value,
    plannedFinishDate: value.plannedFinishDate ?? null,
    plannedQuantity: value.plannedQuantity ?? null,
    plannedStartDate: value.plannedStartDate ?? null,
    unit: value.unit ?? null,
  }));

export const workProgressSchema = z.object({
  note: z.preprocess(emptyToUndefined, z.string().trim().max(2000).optional()),
  quantity: z.coerce
    .number({ error: "Введите выполненный объём числом." })
    .positive({ error: "Выполненный объём должен быть больше нуля." }),
  recordedForDate: optionalDate,
});

export const workProgressReturnSchema = z.object({
  reason: z
    .string()
    .trim()
    .min(1, { error: "Укажите причину возврата." })
    .max(2000),
});

const workFiltersSchema = z.object({
  search: z.string().trim().catch(""),
  status: z.enum(workStatuses).optional().catch(undefined),
});

function firstString(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export type WorkFilters = z.infer<typeof workFiltersSchema>;

export function parseWorkFilters(input: {
  search?: string | string[];
  status?: string | string[];
}): WorkFilters {
  return workFiltersSchema.parse({
    search: firstString(input.search) ?? "",
    status: firstString(input.status),
  });
}
