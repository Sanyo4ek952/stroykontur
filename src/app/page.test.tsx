import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";

import HomePage from "./page";

afterEach(cleanup);

describe("HomePage", () => {
  it("renders the initial application status", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: "Строительный объект" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Система готова к настройке")).toBeVisible();
  });

  it("shows the local-only scenario and network warning for local Supabase", () => {
    const previousUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    process.env.NEXT_PUBLIC_SUPABASE_URL = "http://127.0.0.1:54321";

    try {
      render(<HomePage />);

      expect(screen.getByText("Локальное демо")).toBeVisible();
      expect(
        screen.getByRole("heading", {
          name: "Краткий сценарий двух организаций",
        }),
      ).toBeVisible();
      expect(
        screen.getByRole("link", { name: "Краткий сценарий" }),
      ).toHaveAttribute("href", "#local-demo-scenario");
      expect(screen.getByRole("note")).toHaveTextContent(
        /localhost сам по себе недоступен/,
      );
      expect(screen.getByRole("note")).toHaveTextContent(/offline sync/);
    } finally {
      if (previousUrl === undefined) {
        delete process.env.NEXT_PUBLIC_SUPABASE_URL;
      } else {
        process.env.NEXT_PUBLIC_SUPABASE_URL = previousUrl;
      }
    }
  });
});
