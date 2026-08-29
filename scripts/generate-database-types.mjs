import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { format } from "prettier";

const projectRoot = fileURLToPath(new URL("..", import.meta.url));
const cliPath = resolve(projectRoot, "node_modules/supabase/dist/supabase.js");
const outputPath = resolve(
  projectRoot,
  "src/server/supabase/database.types.ts",
);
const result = spawnSync(
  process.execPath,
  [cliPath, "gen", "types", "--lang", "typescript", "--local"],
  {
    cwd: projectRoot,
    encoding: "utf8",
    stdio: ["inherit", "pipe", "inherit"],
    maxBuffer: 10 * 1024 * 1024,
  },
);

if (result.error) {
  throw result.error;
}

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const generatedTypes = await format(`${result.stdout.trimEnd()}\n`, {
  parser: "typescript",
  endOfLine: "lf",
});

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, generatedTypes, "utf8");
