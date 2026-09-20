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
    ["READY_FOR_INSPECTION", []],
    ["ACCEPTED", ["close"]],
    ["CLOSED", []],
    ["REWORK_REQUIRED", []],
    ["PAUSED", []],
    ["CANCELLED", []],
  ])("projects only approved transitions for %s", (status, expected) => {
    expect(
      getWorkLifecycleActions(status as string, capabilities, {
        activeBlockerCount: status === "IN_PROGRESS" ? 1 : 0,
        isReady: true,
      }),
    ).toEqual(expected);
  });
  it.each([
    ["PLANNED", "canMarkWorkReady", "ready"],
    ["READY", "canStartWork", "start"],
    ["IN_PROGRESS", "canMarkWorkReadyForInspection", "readyForInspection"],
    ["IN_PROGRESS", "canBlockWork", "block"],
    ["BLOCKED", "canBlockWork", "resume"],
    ["ACCEPTED", "canCloseWork", "close"],
  ])("hides %s action without %s", (status, permission, action) => {
    expect(
      getWorkLifecycleActions(
        status,
        { ...capabilities, [permission]: false },
        { activeBlockerCount: status === "IN_PROGRESS" ? 1 : 0, isReady: true },
      ),
    ).not.toContain(action);
  });

  it("hides ready/start while readiness fails", () => {
    const context = { activeBlockerCount: 0, isReady: false };
    expect(getWorkLifecycleActions("PLANNED", capabilities, context)).toEqual(
      [],
    );
    expect(getWorkLifecycleActions("READY", capabilities, context)).toEqual([]);
  });

  it("requires an active blocker to block and none to resume", () => {
    expect(
      getWorkLifecycleActions("IN_PROGRESS", capabilities, {
        activeBlockerCount: 0,
        isReady: false,
      }),
    ).not.toContain("block");
    expect(
      getWorkLifecycleActions("BLOCKED", capabilities, {
        activeBlockerCount: 1,
        isReady: false,
      }),
    ).not.toContain("resume");
  });
});
