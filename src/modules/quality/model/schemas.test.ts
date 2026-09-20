import { describe, expect, it } from "vitest";

import { inspectionResultSchema } from "./schemas";

describe("inspectionResultSchema", () => {
  it("trims and accepts a result note", () => {
    expect(
      inspectionResultSchema.parse({
        resultNote: "  Работы соответствуют РД.  ",
      }),
    ).toEqual({ resultNote: "Работы соответствуют РД." });
  });

  it.each(["", "   ", "x".repeat(2001)])(
    "rejects invalid note",
    (resultNote) => {
      expect(inspectionResultSchema.safeParse({ resultNote }).success).toBe(
        false,
      );
    },
  );
});
