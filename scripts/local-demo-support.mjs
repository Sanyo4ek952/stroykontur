import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const loopbackHosts = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

export const demoAccounts = {
  pto: {
    email: "demo@construction.test",
    password: "Demo-Task012-2026!",
  },
  manager: {
    email: "work.manager@construction.test",
    password: "Work-Task015-2026!",
  },
  field: {
    email: "field@construction.test",
    password: "Field-Task020-2026!",
  },
  siteManager: {
    email: "site.manager@construction.test",
    password: "SiteManager-Task021-2026!",
  },
  areaBConfirmer: {
    email: "site.manager.b@construction.test",
    password: "SiteManagerB-Task022-2026!",
  },
  quality: {
    email: "work.quality@construction.test",
    password: "Work-Task018-2026!",
  },
};

export const demoIds = {
  organization: "00120000-0000-0000-0000-000000000001",
  subcontractorOrganization: "00120000-0000-0000-0000-000000000002",
  project: "10120000-0000-0000-0000-000000000001",
  projectOrganization: "20120000-0000-0000-0000-000000000001",
  subcontractorProjectOrganization: "20120000-0000-0000-0000-000000000002",
  demoUser: "f0260000-0000-0000-0000-000000000001",
  workCreatorUser: "f0260000-0000-0000-0000-000000000002",
  workQualityUser: "f0260000-0000-0000-0000-000000000003",
  fieldUser: "f0260000-0000-0000-0000-000000000004",
  siteManagerUser: "f0260000-0000-0000-0000-000000000005",
  areaBConfirmerUser: "f0260000-0000-0000-0000-000000000006",
  projectMember: "30120000-0000-0000-0000-000000000001",
  workCreatorProjectMember: "30120000-0000-0000-0000-000000000002",
  workQualityProjectMember: "30120000-0000-0000-0000-000000000018",
  fieldProjectMember: "30120000-0000-0000-0000-000000000020",
  siteManagerProjectMember: "30120000-0000-0000-0000-000000000121",
  areaBConfirmerProjectMember: "30220000-0000-0000-0000-000000000001",
  dailyReportWork: "70220000-0000-0000-0000-000000000001",
  qualityWork: "70120000-0000-0000-0000-000000000024",
  areaA: "40120000-0000-0000-0000-000000000001",
  areaB: "40120000-0000-0000-0000-000000000002",
  lifecycleWork: "70120000-0000-0000-0000-000000000018",
  lifecycleWorkAssignment: "71120000-0000-0000-0000-000000000018",
  lifecycleDocumentWorkLink: "80120000-0000-0000-0000-000000000018",
  reworkWork: "70120000-0000-0000-0000-000000000019",
  technicalDocument: "50120000-0000-0000-0000-000000000001",
  documentRevision: "60120000-0000-0000-0000-000000000001",
  work: "70120000-0000-0000-0000-000000000001",
  prerequisiteWork: "70120000-0000-0000-0000-000000000002",
  blockedWork: "70120000-0000-0000-0000-000000000003",
  workAssignment: "71120000-0000-0000-0000-000000000001",
  blockedWorkAssignment: "71120000-0000-0000-0000-000000000002",
  workDependencyPrerequisite: "72120000-0000-0000-0000-000000000001",
  workDependencyBlocked: "72120000-0000-0000-0000-000000000002",
  workProgress: "73120000-0000-0000-0000-000000000001",
  documentWorkLink: "80120000-0000-0000-0000-000000000001",
  documentIssueForWork: "90120000-0000-0000-0000-000000000001",
  issueTechnicalDocument: "50120000-0000-0000-0000-000000000017",
  issueDocumentRevision: "60120000-0000-0000-0000-000000000017",
  issueWork: "70120000-0000-0000-0000-000000000017",
  issueWorkAssignment: "71120000-0000-0000-0000-000000000017",
  issueDocumentWorkLink: "80120000-0000-0000-0000-000000000017",
};

export function parseSupabaseConfig(source) {
  let section = "";
  let projectId;
  let apiPort;

  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.replace(/#.*$/, "").trim();
    if (!line) continue;
    const sectionMatch = line.match(/^\[([^\]]+)]$/);
    if (sectionMatch) {
      section = sectionMatch[1];
      continue;
    }
    const valueMatch = line.match(/^([a-z_]+)\s*=\s*(?:"([^"]*)"|(\d+))$/i);
    if (!valueMatch) continue;
    const [, key, stringValue, numberValue] = valueMatch;
    if (!section && key === "project_id") projectId = stringValue;
    if (section === "api" && key === "port") apiPort = Number(numberValue);
  }

  if (!projectId || !Number.isInteger(apiPort)) {
    throw new Error(
      "В supabase/config.toml должны быть заданы project_id и [api].port.",
    );
  }

  return { apiPort, projectId };
}

export function readLocalProjectConfig(root = process.cwd()) {
  const configPath = resolve(root, "supabase", "config.toml");
  if (!existsSync(configPath)) {
    throw new Error("Не найден supabase/config.toml текущего проекта.");
  }
  return parseSupabaseConfig(readFileSync(configPath, "utf8"));
}

export function validateLocalSupabaseUrl(value, config) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Supabase URL имеет неверный формат.");
  }

  if (
    url.protocol !== "http:" ||
    !loopbackHosts.has(url.hostname) ||
    url.port !== String(config.apiPort) ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    throw new Error(
      `Команда работает только с loopback Supabase из текущего config.toml (порт ${config.apiPort}).`,
    );
  }

  return url.toString().replace(/\/$/, "");
}

export function parseEnvironment(source) {
  const result = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    result[key] = value;
  }
  return result;
}

export function readLocalSupabaseEnvironment({
  requirePrivileged = true,
  root = process.cwd(),
} = {}) {
  const config = readLocalProjectConfig(root);
  const cliPath = resolve(
    root,
    "node_modules",
    "supabase",
    "dist",
    "supabase.js",
  );
  if (!existsSync(cliPath)) {
    throw new Error(
      "Зависимости не установлены. Сначала выполните pnpm install.",
    );
  }

  let output;
  try {
    output = execFileSync(process.execPath, [cliPath, "status", "-o", "env"], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch {
    throw new Error(
      "Локальный Supabase не запущен для текущего проекта. Выполните pnpm demo:prepare.",
    );
  }

  const environment = parseEnvironment(output);
  const url = validateLocalSupabaseUrl(environment.API_URL ?? "", config);
  const publishableKey = environment.PUBLISHABLE_KEY ?? environment.ANON_KEY;
  const privilegedKey = environment.SECRET_KEY ?? environment.SERVICE_ROLE_KEY;

  if (!publishableKey || (requirePrivileged && !privilegedKey)) {
    throw new Error("Local Supabase не вернул обязательные ключи проекта.");
  }

  return { config, privilegedKey, publishableKey, url };
}

export function readPublicEnvironment(root = process.cwd()) {
  const environmentPath = resolve(root, ".env.local");
  if (!existsSync(environmentPath)) return null;
  return parseEnvironment(readFileSync(environmentPath, "utf8"));
}

export function assertExistingPublicEnvironmentIsLocal(root = process.cwd()) {
  const environment = readPublicEnvironment(root);
  const existingUrl = environment?.NEXT_PUBLIC_SUPABASE_URL;
  if (existingUrl) {
    validateLocalSupabaseUrl(existingUrl, readLocalProjectConfig(root));
  }
}

export function mergePublicEnvironment(source, { publishableKey, url }) {
  const managedKeys = new Set([
    "NEXT_PUBLIC_SUPABASE_URL",
    "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  ]);
  const keptLines = source.split(/\r?\n/).filter((line) => {
    const key = line.match(/^\s*([A-Z0-9_]+)\s*=/)?.[1];
    return !key || !managedKeys.has(key);
  });
  while (keptLines.at(-1) === "") keptLines.pop();
  if (keptLines.length > 0) keptLines.push("");
  keptLines.push(
    "# Generated by pnpm demo:prepare. Browser-safe local values only.",
    `NEXT_PUBLIC_SUPABASE_URL=${url}`,
    `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${publishableKey}`,
    "",
  );
  return keptLines.join("\n");
}

export function writePublicEnvironment(environment, root = process.cwd()) {
  const environmentPath = resolve(root, ".env.local");
  const source = existsSync(environmentPath)
    ? readFileSync(environmentPath, "utf8")
    : "";
  writeFileSync(
    environmentPath,
    mergePublicEnvironment(source, environment),
    "utf8",
  );
}

export function localSupabaseCliPath(root = process.cwd()) {
  const cliPath = resolve(
    root,
    "node_modules",
    "supabase",
    "dist",
    "supabase.js",
  );
  if (!existsSync(cliPath)) {
    throw new Error(
      "Зависимости не установлены. Сначала выполните pnpm install.",
    );
  }
  return cliPath;
}
