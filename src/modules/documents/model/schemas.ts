import { z } from "zod";

export const postgresUuidSchema = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

export const documentRevisionStatuses = [
  "draft",
  "registered",
  "under_review",
  "approved",
  "returned",
  "superseded",
  "annulled",
] as const;

const requiredText = (message: string) =>
  z.string().trim().min(1, { error: message });

export const technicalDocumentSchema = z.object({
  code: requiredText("Введите код документа."),
  title: requiredText("Введите название документа."),
});

export const documentRevisionSchema = z.object({
  revisionCode: requiredText("Введите код ревизии."),
});

const documentFiltersSchema = z.object({
  search: z.string().trim().catch(""),
  status: z.enum(documentRevisionStatuses).optional().catch(undefined),
});

function firstString(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export type DocumentFilters = z.infer<typeof documentFiltersSchema>;

export function parseDocumentFilters(input: {
  search?: string | string[];
  status?: string | string[];
}): DocumentFilters {
  return documentFiltersSchema.parse({
    search: firstString(input.search) ?? "",
    status: firstString(input.status),
  });
}
