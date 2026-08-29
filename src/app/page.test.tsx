import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import HomePage from "./page";

describe("HomePage", () => {
  it("renders the initial application status", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: "Строительный объект" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Система готова к настройке")).toBeVisible();
  });
});
