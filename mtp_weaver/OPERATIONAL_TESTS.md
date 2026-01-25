# OPERATIONAL_TESTS.md: Engineering Grounding

This document specifies the experimental tests to verify that the derived "Shadows" (Time, Human Projections) correctly map to the Invariant Base Structure.

---

## 1. Threshold Experiment: The Death of Time

- **Goal**: Identify the noise rate $p$ at which the Recovery Semigroup ceases to function.
- **Method**:
    1. Randomly delete $p \%$ of edges $E$ in a mock Tensor Network.
    2. Apply the Recovery algorithm $\mathcal{R}$.
    3. Measure the stability of the $H_1$ loop.
- **Success Criteria**: At $p = p_c$ (code threshold), $\Delta t$ should become undefined. Time "stops" when the invariant cannot be restored.

---

## 2. Projection Consistency Test

- **Goal**: Verify that the Human Projection $\Pi_h$ preserves the core invariants.
- **Method**:
    1. Apply $\Pi_h$ (Bond dimension reduction) to a stable network $\mathcal{N}$.
    2. Verify if the Jones Polynomial (Placeholder for $H_1$ invariant) remains unchanged.
- **Success Criteria**: If the Jones Polynomial changes, the projection is "invalid" (cognitive rupture).

---

## 3. Network Family Comparison

- **Benchmark**: Compare the recovery efficiency of different TN topologies (MERA, PEPS, Random).
- **Goal**: Prove that only specific topologies (like those found in Quantum Gravity models) support the emergence of "Stable Time" and "Meaningful Projections."

---
*Derived strictly from v1.0_frozen. No new axioms.*
