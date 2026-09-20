import { describe, expect, it } from "vitest";

import {
  parseWorkFilters,
  workBlockerOpenSchema,
  workBlockerResolveSchema,
  workProgressReturnSchema,
  workSchema,
} from "./schemas";

describe("workSchema", () => {
  it("trims required fields and accepts coherent planning data", () => {
    expect(
      workSchema.parse({
        code: "  WORK-01 ",
        plannedFinishDate: "2026-09-10",
        plannedQuantity: "12.5",
        plannedStartDate: "2026-09-01",
        title: "  Монтаж конструкций ",
        unit: " м³ ",
      }),
    ).toEqual({
      code: "WORK-01",
      plannedFinishDate: "2026-09-10",
      plannedQuantity: 12.5,
      plannedStartDate: "2026-09-01",
      title: "Монтаж конструкций",
      unit: "м³",
    });
  });

  it("requires quantity and unit together", () => {
    const result = workSchema.safeParse({
      code: "WORK-01",
      plannedQuantity: "10",
      title: "Работа",
      unit: "",
    });

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.flatten().fieldErrors.unit).toContain(
        "Плановый объём и единицу измерения нужно указать вместе.",
      );
    }
  });

  it("rejects a non-positive quantity and reversed dates", () => {
    const result = workSchema.safeParse({
      code: "WORK-01",
      plannedFinishDate: "2026-09-01",
      plannedQuantity: "0",
      plannedStartDate: "2026-09-10",
      title: "Работа",
      unit: "м³",
    });

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.flatten().fieldErrors.plannedQuantity).toContain(
        "Плановый объём должен быть больше нуля.",
      );
      expect(result.error.flatten().fieldErrors.plannedFinishDate).toContain(
        "Дата окончания не может быть раньше даты начала.",
      );
    }
  });
});

describe("workProgressReturnSchema", () => {
  it("requires and trims a bounded return reason", () => {
    expect(
      workProgressReturnSchema.parse({ reason: "  Неверный объём  " }),
    ).toEqual({
      reason: "Неверный объём",
    });
    expect(workProgressReturnSchema.safeParse({ reason: "   " }).success).toBe(
      false,
    );
  });
});

describe("WorkBlocker schemas", () => {
  it("trims a valid controlled blocker", () => {
    expect(
      workBlockerOpenSchema.parse({
        category: "TECHNICAL",
        description: "  Требуется доступ к узлу  ",
        title: "  Нет доступа  ",
      }),
    ).toEqual({
      category: "TECHNICAL",
      description: "Требуется доступ к узлу",
      title: "Нет доступа",
    });
  });

  it("rejects unknown categories and empty resolution notes", () => {
    expect(
      workBlockerOpenSchema.safeParse({
        category: "SUPPLY",
        description: "Причина",
        title: "Проблема",
      }).success,
    ).toBe(false);
    expect(
      workBlockerResolveSchema.safeParse({ resolutionNote: "  " }).success,
    ).toBe(false);
  });
});

describe("parseWorkFilters", () => {
  it("normalizes URL-driven search and accepts known statuses", () => {
    expect(
      parseWorkFilters({ search: ["  фундамент  "], status: "READY" }),
    ).toEqual({ search: "фундамент", status: "READY" });
  });

  it("ignores an unknown status", () => {
    expect(parseWorkFilters({ status: "NOT_A_STATUS" })).toEqual({
      search: "",
      status: undefined,
    });
  });
});
