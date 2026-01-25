# SHADOW_AUDIT_WEIGHTS.json (Conceptual Logic)

This document formalizes the "Weighting" of the derived Shadows (Time, Human Projections) within the MTP Weaver's Consensus Driver.

---

## 1. Metric Mapping: Recovery to Frustration

The following theoretical weights are assigned to balance "Invariant Stability" with "Human Observability":

### A. Temporal Inertia Weight ($\omega_t = 0.40$)

- **Measured by**: `drift` metric in the Braid Engine.
- **Logic**: Low temporal cost implies high "Stability." High recovery cost ($\Delta t$) triggers an immediate WARNING.
- **Goal**: Detect changes that violate the history invariant (Hysteresis).

### B. Projection Fidelity Weight ($\omega_h = 0.45$)

- **Measured by**: `inflation` and `c_fail` metrics.
- **Logic**: If the bond dimension of the input exceeds $\Pi_h$ boundaries, the output is "Incomprehensible."
- **Goal**: Prevents non-local "Conceptual Knots" from manifesting as hallucinations.

### C. Threshold Veto ($\text{Veto} = \text{CRITICAL}$)

- **Condition**: If Noise $(p) > p_c$ (Topological Code Threshold).
- **Logic**: When the Invariant Skeleton ($H_1$) is broken, the Recovery Semigroup halts.
- **Result**: Immediate BLOCK.

---

## 2. Decision Logic

Final Score = $(\omega_t \times \text{History\_Audit}) + (\omega_h \times \text{Logic\_Audit})$

- If **Physics\_Audit == CRITICAL**, ignore Score -> **BLOCK**.
- If Final Score > 0.70 -> **BLOCK**.
- If Final Score > 0.40 -> **WARN**.

---
*Derived from HUMAN_AS_PROJECTION.md and TIME_FROM_RECOVERY.md.*
