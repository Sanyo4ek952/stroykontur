export type WorkProgressTotals = {
  confirmed: number;
  reported: number;
  returned: number;
};

type ProgressEntryForTotals = {
  confirmation_status: string;
  quantity: number;
};

export function getWorkProgressTotals(
  entries: readonly ProgressEntryForTotals[],
): WorkProgressTotals {
  return entries.reduce<WorkProgressTotals>(
    (totals, entry) => {
      const quantity = Number(entry.quantity);
      if (entry.confirmation_status === "CONFIRMED") {
        totals.confirmed += quantity;
      } else if (entry.confirmation_status === "RETURNED") {
        totals.returned += quantity;
      } else {
        totals.reported += quantity;
      }
      return totals;
    },
    { confirmed: 0, reported: 0, returned: 0 },
  );
}

export function getWorkProgressStatusLabel(
  confirmationStatus: string,
  returnReason: string | null,
) {
  switch (confirmationStatus) {
    case "CONFIRMED":
      return "Подтверждено";
    case "RETURNED":
      return returnReason ? `Возвращено: ${returnReason}` : "Возвращено";
    default:
      return "Ожидает подтверждения";
  }
}
