import { describe, expect, it } from "vitest";
import {
  getWorkLifecycleActions,
  type WorkLifecycleCapabilities,
} from "./lifecycle";
const capabilities: WorkLifecycleCapabilities = {
  canAcceptWork: true,
  canBlockWork: true,
  canCloseWork: true,
  canMarkWorkReady: true,
  canMarkWorkReadyForInspection: true,
  canRequireWorkRework: true,
  canStartWork: true,
};
describe("Work lifecycle controls", () => {
  it.each([
    ["PLANNED", ["ready"]],
    ["READY", ["start"]],
    ["IN_PROGRESS", ["readyForInspection", "block"]],
    ["BLOCKED", ["resume"]],
    ["READY_FOR_INSPECTION", ["accept", "rework"]],
    ["ACCEPTED", ["close"]],
    ["CLOSED", []],
    ["REWORK_REQUIRED", []],
    ["PAUSED", []],
    ["CANCELLED", []],
  ])("projects only approved transitions for %s", (status, expected) => {
    expect(getWorkLifecycleActions(status as string, capabilities)).toEqual(
      expected,
    );
  });
  it.each([
    ["PLANNED", "canMarkWorkReady", "ready"],
    ["READY", "canStartWork", "start"],
    ["IN_PROGRESS", "canMarkWorkReadyForInspection", "readyForInspection"],
    ["IN_PROGRESS", "canBlockWork", "block"],
    ["BLOCKED", "canBlockWork", "resume"],
    ["READY_FOR_INSPECTION", "canAcceptWork", "accept"],
    ["READY_FOR_INSPECTION", "canRequireWorkRework", "rework"],
    ["ACCEPTED", "canCloseWork", "close"],
  ])("hides %s action without %s", (status, permission, action) => {
    expect(
      getWorkLifecycleActions(status, { ...capabilities, [permission]: false }),
    ).not.toContain(action);
  });
});
