export const workBlockerCategories = [
  "DOCUMENTATION",
  "DEPENDENCY",
  "ASSIGNMENT",
  "MATERIAL",
  "SAFETY",
  "QUALITY",
  "TECHNICAL",
  "OTHER",
] as const;

export type WorkBlockerCategory = (typeof workBlockerCategories)[number];
export type WorkReadinessCheckKey =
  "area" | "assignment" | "working_documentation" | "dependencies" | "blockers";

export type WorkReadinessItem = {
  category?: string;
  code?: string;
  id: string;
  status?: string;
  title: string;
};

export type WorkReadinessCheck = {
  code: string | null;
  items: WorkReadinessItem[];
  key: WorkReadinessCheckKey;
  message: string;
  passed: boolean;
};

export type WorkReadiness = {
  checks: WorkReadinessCheck[];
  isReady: boolean;
  workId: string;
};

export const workBlockerCategoryLabels: Record<WorkBlockerCategory, string> = {
  ASSIGNMENT: "Ответственный",
  DEPENDENCY: "Зависимость",
  DOCUMENTATION: "Документация",
  MATERIAL: "Материал",
  OTHER: "Другое",
  QUALITY: "Качество",
  SAFETY: "Охрана труда",
  TECHNICAL: "Техническая проблема",
};

export const workBlockerStatusLabels = {
  OPEN: "Активна",
  RESOLVED: "Устранена",
} as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
export function parseWorkReadiness(value: unknown): WorkReadiness {
  if (!isRecord(value) || typeof value.is_ready !== "boolean") {
    throw new Error("Invalid Work readiness response");
  }
  if (typeof value.work_id !== "string" || !Array.isArray(value.checks)) {
    throw new Error("Invalid Work readiness response");
  }
  const checks = value.checks.map((check): WorkReadinessCheck => {
    if (
      !isRecord(check) ||
      typeof check.key !== "string" ||
      typeof check.passed !== "boolean" ||
      typeof check.message !== "string" ||
      !Array.isArray(check.items)
    ) {
      throw new Error("Invalid Work readiness check");
    }
    const key = check.key as WorkReadinessCheckKey;
    if (
      ![
        "area",
        "assignment",
        "working_documentation",
        "dependencies",
        "blockers",
      ].includes(key)
    ) {
      throw new Error("Invalid Work readiness check key");
    }
    const items = check.items.map((item): WorkReadinessItem => {
      if (
        !isRecord(item) ||
        typeof item.id !== "string" ||
        typeof item.title !== "string"
      ) {
        throw new Error("Invalid Work readiness item");
      }
      return {
        category: typeof item.category === "string" ? item.category : undefined,
        code: typeof item.code === "string" ? item.code : undefined,
        id: item.id,
        status: typeof item.status === "string" ? item.status : undefined,
        title: item.title,
      };
    });
    return {
      code: typeof check.code === "string" ? check.code : null,
      items,
      key,
      message: check.message,
      passed: check.passed,
    };
  });
  return { checks, isReady: value.is_ready, workId: value.work_id };
}

export function getReadinessFailureMessages(readiness: WorkReadiness) {
  return readiness.checks.flatMap((check) => {
    if (check.passed) return [];
    if (check.key === "dependencies") {
      return check.items.map(
        (item) => `Не завершена зависимая работа ${item.code ?? item.title}`,
      );
    }
    if (check.key === "blockers") {
      return [
        `Есть ${check.items.length} ${pluralizeBlocker(check.items.length)}`,
      ];
    }
    return [check.message];
  });
}

function pluralizeBlocker(count: number) {
  const mod100 = count % 100;
  const mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return "активных блокировок";
  if (mod10 === 1) return "активная блокировка";
  if (mod10 >= 2 && mod10 <= 4) return "активные блокировки";
  return "активных блокировок";
}
