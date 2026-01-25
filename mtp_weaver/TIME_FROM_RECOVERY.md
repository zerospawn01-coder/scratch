# TIME_FROM_RECOVERY.md: The Emergence of Temporal Vector

This document derives **Time, Inertia, and Hysteresis** strictly from the recovery dynamics of the Invariant Base Structure $\mathcal{N}$ defined in `BASE_STRUCTURE_GEOMETRY.md`.

---

## 1. The Arrow of Time: Recovery Semigroup

In a lossy Tensor Network $\mathcal{N}$ with noise $p$, "Time" is not a fundamental variable but a derivation of the **Recovery Map** $\mathcal{R}$.

### Definition: Time's Direction

Let $\mathcal{N}_p$ be a noisy state and $\mathcal{R}$ be a mapping that restores the invariants $(H_1, k)$.
The temporal vector is the sequence of non-invertible transformations:
$$\mathcal{N}^{(t+1)} = \mathcal{R}(\mathcal{N}^{(t)} \otimes \text{Loss})$$

- **Irreversibility**: Since $\mathcal{R}$ involves tracing out degrees of freedom (information loss), it forms a **Semigroup**, not a Group. The inability to invert $\mathcal{R}$ without external energy/information defines the "Arrow of Time."

---

## 2. Inertia: Conservation of Minimal Repair Distance

Physical "Inertia" is derived from the structural cost of maintaining the Fixed-Point Consistency.

### Definition: Inertia

Let $d(\mathcal{N}, \mathcal{N}')$ be the minimal number of local tensor operations required to transition between two invariant states.

- **Inertial Motion**: A sequence of transformations that preserves the minimal repair distance $d$ per recovery step.
- An object "at rest" relative to the Invariant Skeleton is one whose recovery cost does not vary over the semigroup sequence.

---

## 3. Hysteresis: Path-Dependent Convergence

"History" or "Memory" emerges when multiple disparate recovery paths lead to the same Invariant Fixed Point.

### Definition: Hysteresis

If $\exists \text{ paths } P_1, P_2$ such that $\mathcal{R}(P_1) = \mathcal{R}(P_2) = \mathcal{N}_{\text{stable}}$, but the internal tensor configurations $V$ differ, the system exhibits **Hysteresis**.

- The "Logical State" is the same (Error Corrected), but the "Physical Substrate" carries the signature of the specific noise/loss history.
- **Context** is the topological residue of the specific recovery path taken through the network.

---

## 4. Observables

- **$\Delta t$**: Entropy production during the $\mathcal{R}$ operation.
- **Curvature**: Local density of required recovery operations (Equivalent to mass-energy density in the TN mapping).

---
*Derived strictly from v1.0_frozen. No new axioms.*
