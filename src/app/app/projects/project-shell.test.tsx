import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ProjectNavigation } from "./[projectId]/project-navigation";
import { EmptyState } from "./[projectId]/ui";
import { getStatusLabel } from "./status-labels";

describe("project workspace presentation", () => {
  it("renders every workspace navigation entry", () => {
    render(<ProjectNavigation projectId="project-id" />);

    for (const label of [
      "Обзор",
      "Мои задачи",
      "Документы",
      "Работы",
      "Уведомления",
    ]) {
      expect(screen.getByRole("link", { name: label })).toBeInTheDocument();
    }
  });

  it("renders an empty state without crashing", () => {
    render(<EmptyState title="Нет назначенных задач." />);
    expect(
      screen.getByRole("heading", { name: "Нет назначенных задач." }),
    ).toBeInTheDocument();
  });

  it("falls back safely for an unknown status", () => {
    expect(getStatusLabel("WAITING_FOR_EXTERNAL_REVIEW")).toBe(
      "WAITING FOR EXTERNAL REVIEW",
    );
  });
});
