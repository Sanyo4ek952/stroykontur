import "server-only";

import { z } from "zod";

const serverEnvironmentSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

export const serverEnvironment = serverEnvironmentSchema.parse({
  NODE_ENV: process.env.NODE_ENV,
});
