import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { WorkAssignmentControls } from "./assignment-controls";

vi.mock("../assignment-actions", () => ({
  assignWork: vi.fn(),
  reassignWork: vi.fn(),
}));

describe("WorkAssignmentControls", () => {
  it("renders readable radio choices using project_member_id values", () => {
    render(
      <WorkAssignmentControls
        candidates={[
          {
            id: "30120000-0000-0000-0000-000000000002",
            label: "Алексей Воронцов · Директор по строительству",
            name: "Алексей Воронцов",
            role: "Директор по строительству",
          },
        ]}
        currentAssignment={{
          id: "80120000-0000-0000-0000-000000000001",
          responsibleLabel: "Анна Орлова · ПТО",
        }}
        projectId="10120000-0000-0000-0000-000000000001"
        workId="70120000-0000-0000-0000-000000000001"
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "Переназначить" }));

    const candidate = screen.getByRole("radio", {
      name: "Алексей Воронцов · Директор по строительству",
    });
    expect(candidate).toHaveAttribute(
      "value",
      "30120000-0000-0000-0000-000000000002",
    );
    expect(screen.queryByRole("combobox")).not.toBeInTheDocument();
    expect(screen.queryByText(/организац/i)).not.toBeInTheDocument();
    expect(
      screen.getByText("Текущий ответственный: Анна Орлова · ПТО"),
    ).toBeVisible();
  });
});
