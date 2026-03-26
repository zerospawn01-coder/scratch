import type {
  EvolutionaryDelta,
  EvolutionaryRuleState,
  ShadowLearningEvent,
  SincereTag,
} from "../types/constitution";

const NOMOS_BASELINE_R = 0.73;
const NOMOS_MIN_R = 0.68;
const NOMOS_MAX_R = 0.78;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/**
 * Phase 31 prototype:
 * - Learns from previously rejected/degraded operations.
 * - Adjusts dynamic rule hardness (dynamicR) using entropy + baseline drift.
 * - Enforces IGC upper cap through igcCapK <= 1.8.
 */
export class EvolutionaryDeltaEngine {
  private state: EvolutionaryRuleState;

  constructor(initialState?: Partial<EvolutionaryRuleState>) {
    this.state = {
      dynamicR: initialState?.dynamicR ?? NOMOS_BASELINE_R,
      igcCapK: clamp(initialState?.igcCapK ?? 1.8, 0.8, 1.8),
      confidenceFloor: initialState?.confidenceFloor ?? 0.6,
      confidenceCeiling: initialState?.confidenceCeiling ?? 0.85,
    };
  }

  getState(): EvolutionaryRuleState {
    return { ...this.state };
  }

  adaptFromShadowEvent(event: ShadowLearningEvent): EvolutionaryDelta {
    const entropyError = event.observedEntropy - this.state.igcCapK;
    const baselineError = event.baselineR - NOMOS_BASELINE_R;

    // Small bounded adaptation step to avoid rule oscillation.
    const deltaR = clamp((entropyError * 0.015) + (baselineError * 0.05), -0.02, 0.02);
    const nextDynamicR = clamp(this.state.dynamicR + deltaR, NOMOS_MIN_R, NOMOS_MAX_R);

    // Keep IGC strict while allowing tiny compensation below ceiling.
    const nextIgcCapK = clamp(1.8 - Math.max(0, entropyError) * 0.02, 1.6, 1.8);

    this.state = {
      ...this.state,
      dynamicR: nextDynamicR,
      igcCapK: nextIgcCapK,
    };

    const assignedTag = this.assignSincereTag(nextDynamicR, event.observedEntropy);
    const rationale = `entropy_error=${entropyError.toFixed(3)}, baseline_error=${baselineError.toFixed(3)}, delta_r=${deltaR.toFixed(3)}`;

    return {
      nextState: this.getState(),
      assignedTag,
      rationale,
    };
  }

  assignSincereTag(confidence: number, entropy: number): SincereTag {
    if (confidence > this.state.confidenceCeiling) {
      return "[VERIFICATION]";
    }
    if (confidence < this.state.confidenceFloor) {
      return "[SILENCE]";
    }
    if (entropy > this.state.igcCapK) {
      return "[EMERGENCE]";
    }
    return "[UNCERTAIN]";
  }
}
