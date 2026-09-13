import { describe, expect, it } from "vitest";

import { getWorkProgressStatusLabel, getWorkProgressTotals } from "./progress";

describe("work progress confirmation presentation", () => {
  it("counts only confirmed quantities in the production total", () => {
    expect(
      getWorkProgressTotals([
        { confirmation_status: "REPORTED", quantity: 2.5 },
        { confirmation_status: "CONFIRMED", quantity: 4 },
        { confirmation_status: "RETURNED", quantity: 1 },
      ]),
    ).toEqual({ confirmed: 4, reported: 2.5, returned: 1 });
  });

  it("renders the return reason as historical context", () => {
    expect(getWorkProgressStatusLabel("RETURNED", "Неверный объём")).toBe(
      "Возвращено: Неверный объём",
    );
  });
});
