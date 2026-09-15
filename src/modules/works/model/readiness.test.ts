import { describe, expect, it } from "vitest";

import {
  getReadinessFailureMessages,
  parseWorkReadiness,
  workBlockerCategoryLabels,
  workBlockerStatusLabels,
} from "./readiness";

describe("Work readiness presentation", () => {
  it("maps all failed checks and every incomplete dependency", () => {
    const readiness = parseWorkReadiness({
      checks: [
        {
          code: "AREA_MISSING",
          items: [],
          key: "area",
          message: "Зона не определена",
          passed: false,
        },
        {
          code: "DEPENDENCY_INCOMPLETE",
          items: [
            { code: "W-1", id: "1", status: "PLANNED", title: "Первая" },
            { code: "W-2", id: "2", status: "BLOCKED", title: "Вторая" },
          ],
          key: "dependencies",
          message: "Есть незавершённые предшествующие работы",
          passed: false,
        },
        {
          code: "ACTIVE_BLOCKER",
          items: [
            { category: "TECHNICAL", id: "3", title: "Нет доступа" },
            { category: "MATERIAL", id: "4", title: "Нет смеси" },
          ],
          key: "blockers",
          message: "Есть активные блокировки",
          passed: false,
        },
      ],
      is_ready: false,
      work_id: "work-id",
    });

    expect(getReadinessFailureMessages(readiness)).toEqual([
      "Зона не определена",
      "Не завершена зависимая работа W-1",
      "Не завершена зависимая работа W-2",
      "Есть 2 активные блокировки",
    ]);
  });

  it("provides stable Russian category and status labels", () => {
    expect(workBlockerCategoryLabels.TECHNICAL).toBe("Техническая проблема");
    expect(workBlockerStatusLabels.OPEN).toBe("Активна");
    expect(workBlockerStatusLabels.RESOLVED).toBe("Устранена");
  });

  it("rejects malformed database responses", () => {
    expect(() => parseWorkReadiness({ is_ready: true })).toThrow(
      "Invalid Work readiness response",
    );
  });
});
