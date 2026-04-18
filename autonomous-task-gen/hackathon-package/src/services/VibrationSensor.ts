import type { CausalForecast, SincereTag, VibrationSignal } from "../types/constitution";

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/**
 * Phase 32 prototype:
 * Predicts execution resistance before Guard-2 violation occurs.
 */
export class VibrationSensor {
  private readonly kUpperBound: number;

  constructor(kUpperBound = 1.8) {
    this.kUpperBound = kUpperBound;
  }

  forecast(signal: VibrationSignal): CausalForecast {
    const entropyPressure = clamp(signal.entropy / this.kUpperBound, 0, 1.5);
    const gradientPressure = clamp(signal.gradient, 0, 1);
    const confidenceRelief = clamp(signal.confidence, 0, 1);

    const rawRisk = (entropyPressure * 0.45) + (gradientPressure * 0.4) + ((1 - confidenceRelief) * 0.35);
    const riskScore = clamp(rawRisk, 0, 1);

    const recommendedTag = this.recommendTag(riskScore, signal.entropy, signal.confidence);
    const probablePath = riskScore < 0.45 ? "RESISTANCE_ZERO" : "RESISTANCE_RISE";
    const rationale = `risk=${riskScore.toFixed(3)}, entropy=${signal.entropy.toFixed(3)}, gradient=${signal.gradient.toFixed(3)}, confidence=${signal.confidence.toFixed(3)}`;

    return {
      riskScore,
      recommendedTag,
      probablePath,
      rationale,
    };
  }

  private recommendTag(riskScore: number, entropy: number, confidence: number): SincereTag {
    if (confidence > 0.88 && riskScore < 0.4) {
      return "[VERIFICATION]";
    }
    if (confidence < 0.55) {
      return "[SILENCE]";
    }
    if (entropy > this.kUpperBound || riskScore > 0.55) {
      return "[EMERGENCE]";
    }
    return "[UNCERTAIN]";
  }
}
