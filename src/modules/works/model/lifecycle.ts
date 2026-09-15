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

export type WorkLifecycleReadiness = {
  activeBlockerCount: number;
  isReady: boolean;
};

// UI projection of WF-05; named DB commands remain the security boundary.
export function getWorkLifecycleActions(
  status: string,
  capabilities: WorkLifecycleCapabilities,
  readiness: WorkLifecycleReadiness = {
    activeBlockerCount: 0,
    isReady: true,
  },
): WorkLifecycleActionName[] {
  const actions: WorkLifecycleActionName[] = [];
  if (
    status === "PLANNED" &&
    capabilities.canMarkWorkReady &&
    readiness.isReady
  )
    actions.push("ready");
  if (status === "READY" && capabilities.canStartWork && readiness.isReady)
    actions.push("start");
  if (status === "IN_PROGRESS") {
    if (capabilities.canMarkWorkReadyForInspection)
      actions.push("readyForInspection");
    if (capabilities.canBlockWork && readiness.activeBlockerCount > 0)
      actions.push("block");
  }
  if (
    status === "BLOCKED" &&
    capabilities.canBlockWork &&
    readiness.activeBlockerCount === 0
  )
    actions.push("resume");
  // TASK-024 owns acceptance controls through an Inspection. The legacy
  // accept/rework RPCs remain DB compatibility boundaries, not UI shortcuts.
  if (status === "ACCEPTED" && capabilities.canCloseWork) actions.push("close");
  return actions;
}
