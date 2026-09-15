import { z } from "zod";
import {
  postgresUuidSchema,
  workProgressSchema,
  workProgressReturnSchema,
} from "@/modules/works/model/schemas";

export const dailyReportStatuses = [
  "DRAFT",
  "SUBMITTED",
  "CONFIRMED",
  "RETURNED",
] as const;
export const dailyReportDraftSchema = z.object({
  workersCount: z.coerce.number().int().min(0).max(100000),
  summary: z.string().trim().max(4000),
  problems: z.string().trim().max(4000),
  commandId: postgresUuidSchema,
});
export const createDailyReportSchema = dailyReportDraftSchema.extend({
  projectAreaId: postgresUuidSchema,
  reportDate: z.iso.date(),
});
export const addDailyReportProgressSchema = workProgressSchema
  .pick({ quantity: true, note: true })
  .extend({
    workId: postgresUuidSchema,
    commandId: postgresUuidSchema,
  });
export const returnDailyReportSchema = workProgressReturnSchema.extend({
  commandId: postgresUuidSchema,
});
