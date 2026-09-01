const statusLabels: Record<string, string> = {
  ACCEPTED: "Принята",
  ASSIGNED: "Назначена",
  BLOCKED: "Заблокирована",
  CANCELLED: "Отменена",
  CLOSED: "Закрыта",
  DETECTED: "Требует внимания",
  DONE: "Выполнена",
  IN_PROGRESS: "В работе",
  OPEN: "Открыта",
  OVERDUE: "Просрочена",
  PAUSED: "Приостановлена",
  PLANNED: "Запланирована",
  READY: "Готова",
  READY_FOR_INSPECTION: "Готова к проверке",
  REWORK_REQUIRED: "Требует исправления",
  VERIFICATION: "На подтверждении",
  active: "Активный",
  annulled: "Аннулирована",
  approved: "Согласована",
  archived: "Архивный",
  cancelled: "Отменён",
  draft: "Черновик",
  registered: "Зарегистрирована",
  returned: "Возвращена",
  superseded: "Заменена",
  under_review: "На проверке",
};

export function getStatusLabel(status: string) {
  return statusLabels[status] ?? status.replaceAll("_", " ");
}

export function getTaskTypeLabel(taskType: string) {
  return taskType === "document_impact_review"
    ? "Проверить влияние документа"
    : taskType.replaceAll("_", " ");
}
