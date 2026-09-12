import { z } from "zod";
import { postgresUuidSchema } from "./schemas";

export const assignWorkSchema = z.object({
  projectId: postgresUuidSchema,
  workId: postgresUuidSchema,
  commandId: postgresUuidSchema,
  newProjectMemberId: postgresUuidSchema,
  reason: z.string().trim().max(2000),
});
export const reassignWorkSchema = assignWorkSchema.extend({
  expectedCurrentAssignmentId: postgresUuidSchema,
  reason: z.string().trim().min(1).max(2000),
});
export type AssignWorkInput = z.infer<typeof assignWorkSchema>;
export type ReassignWorkInput = z.infer<typeof reassignWorkSchema>;
