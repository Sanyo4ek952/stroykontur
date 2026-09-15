import { describe, expect, it } from "vitest";

import {
  inspectionRequestStatusLabels,
  inspectionStatusLabels,
} from "./presentation";

describe("quality inspection presentation", () => {
  it("maps every TASK-024 status", () => {
    expect(Object.keys(inspectionRequestStatusLabels).sort()).toEqual([
      "REQUESTED",
      "SCHEDULED",
    ]);
    expect(Object.keys(inspectionStatusLabels).sort()).toEqual([
      "ACCEPTED",
      "IN_INSPECTION",
      "SCHEDULED",
    ]);
  });
});
