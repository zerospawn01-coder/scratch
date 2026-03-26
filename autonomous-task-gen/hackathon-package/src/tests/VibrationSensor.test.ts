import { describe, expect, it } from "vitest";
import { VibrationSensor } from "../services/VibrationSensor";
import type { VibrationSignal } from "../types/constitution";

function signal(overrides?: Partial<VibrationSignal>): VibrationSignal {
  return {
    sourceId: "agent-001",
    confidence: 0.75,
    entropy: 1.7,
    gradient: 0.4,
    observedAt: new Date("2026-03-24T00:00:00.000Z").toISOString(),
    ...overrides,
  };
}

describe("VibrationSensor", () => {
  it("predicts low-risk zero-resistance path for calm signals", () => {
    const sensor = new VibrationSensor(1.8);
    const forecast = sensor.forecast(signal({ confidence: 0.92, entropy: 1.2, gradient: 0.1 }));

    expect(forecast.riskScore).toBeLessThan(0.45);
    expect(forecast.probablePath).toBe("RESISTANCE_ZERO");
    expect(forecast.recommendedTag).toBe("[VERIFICATION]");
  });

  it("predicts emergence when entropy exceeds K upper bound", () => {
    const sensor = new VibrationSensor(1.8);
    const forecast = sensor.forecast(signal({ confidence: 0.72, entropy: 2.0, gradient: 0.5 }));

    expect(forecast.recommendedTag).toBe("[EMERGENCE]");
    expect(forecast.probablePath).toBe("RESISTANCE_RISE");
  });

  it("recommends silence for very low confidence", () => {
    const sensor = new VibrationSensor(1.8);
    const forecast = sensor.forecast(signal({ confidence: 0.4, entropy: 1.4, gradient: 0.3 }));

    expect(forecast.recommendedTag).toBe("[SILENCE]");
  });
});
