import { describe, expect, it } from "vitest";
import { EvolutionaryDeltaEngine } from "../services/EvolutionaryDeltaEngine";
import type { ShadowLearningEvent } from "../types/constitution";

function event(overrides?: Partial<ShadowLearningEvent>): ShadowLearningEvent {
  return {
    runId: "run_shadow_01",
    reason: "manual_degraded_approval",
    baselineR: 0.73,
    observedEntropy: 1.8,
    approvedAt: new Date("2026-03-24T00:00:00.000Z").toISOString(),
    ...overrides,
  };
}

describe("EvolutionaryDeltaEngine", () => {
  it("keeps igcCapK at or below 1.8 after adaptation", () => {
    const engine = new EvolutionaryDeltaEngine();
    const result = engine.adaptFromShadowEvent(event({ observedEntropy: 2.2 }));

    expect(result.nextState.igcCapK).toBeLessThanOrEqual(1.8);
    expect(result.nextState.igcCapK).toBeGreaterThanOrEqual(1.6);
  });

  it("adjusts dynamicR with bounded step and keeps it in nominal range", () => {
    const engine = new EvolutionaryDeltaEngine({ dynamicR: 0.73 });
    const result = engine.adaptFromShadowEvent(event({ observedEntropy: 2.0, baselineR: 0.76 }));

    expect(result.nextState.dynamicR).toBeGreaterThanOrEqual(0.68);
    expect(result.nextState.dynamicR).toBeLessThanOrEqual(0.78);
    expect(result.nextState.dynamicR).not.toBe(0.73);
  });

  it("assigns EMERGENCE when entropy exceeds cap within confidence band", () => {
    const engine = new EvolutionaryDeltaEngine({ dynamicR: 0.72, igcCapK: 1.75 });
    const tag = engine.assignSincereTag(0.72, 1.79);
    expect(tag).toBe("[EMERGENCE]");
  });

  it("assigns SILENCE for low-confidence states", () => {
    const engine = new EvolutionaryDeltaEngine({ confidenceFloor: 0.6, confidenceCeiling: 0.85 });
    const tag = engine.assignSincereTag(0.55, 1.2);
    expect(tag).toBe("[SILENCE]");
  });

  it("assigns VERIFICATION for high-confidence states", () => {
    const engine = new EvolutionaryDeltaEngine({ confidenceFloor: 0.6, confidenceCeiling: 0.85 });
    const tag = engine.assignSincereTag(0.9, 1.2);
    expect(tag).toBe("[VERIFICATION]");
  });
});
