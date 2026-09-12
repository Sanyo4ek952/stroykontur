import { describe, expect, it } from "vitest";

import {
  documentRevisionSchema,
  parseDocumentFilters,
  technicalDocumentSchema,
} from "./schemas";

describe("document input validation", () => {
  it("trims valid document fields and rejects blank values", () => {
    expect(
      technicalDocumentSchema.parse({ code: "  КЖ-02 ", title: "  Стены " }),
    ).toEqual({ code: "КЖ-02", title: "Стены" });
    expect(
      technicalDocumentSchema.safeParse({ code: "   ", title: "Стены" })
        .success,
    ).toBe(false);
  });

  it("trims a revision code and rejects a blank revision", () => {
    expect(documentRevisionSchema.parse({ revisionCode: " R3 " })).toEqual({
      revisionCode: "R3",
    });
    expect(
      documentRevisionSchema.safeParse({ revisionCode: "\n\t" }).success,
    ).toBe(false);
  });

  it("normalizes URL filters and ignores an unknown lifecycle status", () => {
    expect(
      parseDocumentFilters({
        search: ["  КЖ ", "ignored"],
        status: "approved",
      }),
    ).toEqual({ search: "КЖ", status: "approved" });
    expect(parseDocumentFilters({ status: "issued_for_work" })).toEqual({
      search: "",
      status: undefined,
    });
  });
});
