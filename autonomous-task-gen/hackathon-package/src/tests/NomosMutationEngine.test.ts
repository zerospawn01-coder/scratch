import { describe, expect, it } from "vitest";
import { NomosMutationEngine } from "../services/NomosMutationEngine";
import type { CausalForecast } from "../types/constitution";

function forecast(overrides?: Partial<CausalForecast>): CausalForecast {
  return {
    riskScore: 0.62,
    recommendedTag: "[EMERGENCE]",
    probablePath: "RESISTANCE_RISE",
    rationale: "synthetic forecast",
    ...overrides,
  };
}

describe("NomosMutationEngine", () => {
  it("does not emit mutation before the first full window", () => {
    const engine = new NomosMutationEngine();
    const r1 = engine.processForecast(forecast({ riskScore: 0.9 }));

    expect(r1).toBeNull();
  });

  it("emits partition mutation when sustained average risk exceeds threshold", () => {
    const engine = new NomosMutationEngine();
    engine.processForecast(forecast({ riskScore: 0.65 }));
    const mutation = engine.processForecast(forecast({ riskScore: 0.62 }));

    expect(mutation).not.toBeNull();
    expect(mutation?.target).toBe("CONTRACT");
    expect(mutation?.action).toBe("PARTITION");
    expect(mutation?.status).toBe("PENDING");
  });

  it("reset clears history so trigger requires full new window", () => {
    const engine = new NomosMutationEngine();
    for (let i = 0; i < 5; i += 1) {
      engine.processForecast(forecast({ riskScore: 0.7 }));
    }

    engine.reset();

    const next = engine.processForecast(forecast({ riskScore: 0.9 }));
    expect(next).toBeNull();
  });
});
