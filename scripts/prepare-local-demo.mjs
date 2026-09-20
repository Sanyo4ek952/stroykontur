import { execFileSync } from "node:child_process";

import {
  assertExistingPublicEnvironmentIsLocal,
  demoAccounts,
  demoIds,
  localSupabaseCliPath,
  readLocalProjectConfig,
  readLocalSupabaseEnvironment,
  writePublicEnvironment,
} from "./local-demo-support.mjs";

const root = process.cwd();

function runLocalSupabase(args, failureMessage, { quiet = false } = {}) {
  try {
    execFileSync(process.execPath, [localSupabaseCliPath(root), ...args], {
      cwd: root,
      stdio: quiet ? ["ignore", "pipe", "pipe"] : "inherit",
    });
  } catch {
    throw new Error(failureMessage);
  }
}

function runSeed() {
  try {
    execFileSync(process.execPath, ["scripts/seed-task-012-demo.mjs"], {
      cwd: root,
      stdio: "inherit",
    });
  } catch {
    throw new Error("Не удалось создать детерминированные demo-данные.");
  }
}

function main() {
  if (Number(process.versions.node.split(".")[0]) !== 22) {
    throw new Error("Для локального демо требуется Node.js 22.");
  }

  readLocalProjectConfig(root);
  assertExistingPublicEnvironmentIsLocal(root);
  runLocalSupabase(
    ["start"],
    "Не удалось запустить local Supabase. Проверьте, что Docker работает.",
    { quiet: true },
  );
  const environment = readLocalSupabaseEnvironment({ root });
  runLocalSupabase(
    ["db", "reset"],
    "Не удалось выполнить clean reset local Supabase.",
  );
  runSeed();
  writePublicEnvironment(environment, root);

  console.log("\nЛокальное демо подготовлено.");
  console.log("Demo URL: http://localhost:3000/");
  console.log(
    `Генподрядчик · директор по строительству: ${demoAccounts.manager.email} / ${demoAccounts.manager.password}`,
  );
  console.log(
    `Субподрядчик · мастер/ПТО: ${demoAccounts.field.email} / ${demoAccounts.field.password}`,
  );
  console.log(
    `Прямой маршрут проекта после входа: http://localhost:3000/app/projects/${demoIds.project}`,
  );
  console.log("Следующий шаг: pnpm demo:verify, затем pnpm dev");
  console.log(
    "Только локально: не публикуйте порты, test credentials или localhost через bind/tunnel.",
  );
}

try {
  main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "Подготовка демо завершилась ошибкой.",
  );
  process.exitCode = 1;
}
