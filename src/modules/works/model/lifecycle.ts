export type WorkLifecycleActionName =
  | "accept"
  | "block"
  | "close"
  | "ready"
  | "readyForInspection"
  | "resume"
  | "rework"
  | "start";

export type WorkLifecycleCapabilities = {
  canAcceptWork: boolean;
  canBlockWork: boolean;
  canCloseWork: boolean;
  canMarkWorkReady: boolean;
  canMarkWorkReadyForInspection: boolean;
  canRequireWorkRework: boolean;
  canStartWork: boolean;
};

// UI projection of WF-05; named DB commands remain the security boundary.
export function getWorkLifecycleActions(
  status: string,
  capabilities: WorkLifecycleCapabilities,
): WorkLifecycleActionName[] {
  const actions: WorkLifecycleActionName[] = [];
  if (status === "PLANNED" && capabilities.canMarkWorkReady)
    actions.push("ready");
  if (status === "READY" && capabilities.canStartWork) actions.push("start");
  if (status === "IN_PROGRESS") {
    if (capabilities.canMarkWorkReadyForInspection)
      actions.push("readyForInspection");
    if (capabilities.canBlockWork) actions.push("block");
  }
  if (status === "BLOCKED" && capabilities.canBlockWork) actions.push("resume");
  if (status === "READY_FOR_INSPECTION") {
    if (capabilities.canAcceptWork) actions.push("accept");
    if (capabilities.canRequireWorkRework) actions.push("rework");
  }
  if (status === "ACCEPTED" && capabilities.canCloseWork) actions.push("close");
  return actions;
}
