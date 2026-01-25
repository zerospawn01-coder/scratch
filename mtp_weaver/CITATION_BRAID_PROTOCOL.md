# CITATION_BRAID_PROTOCOL.md: Mapping Knowledge to Topology

This protocol defines the mapping of citation networks to the **Braid Group ($B_n$)** for the purpose of topological review.

## 1. Mapping Principles

- **Strands ($n$)**: Represent major "Thematic Lineages" or "Research Schools."
- **Generators ($\sigma_i$)**: Represent an **Interaction (Citation/Conflict)** between lineage $i$ and $i+1$.
  - $\sigma_i$: Lineage $i$ cites lineage $i+1$ (positive influence).
  - $\sigma_i^{-1}$: Lineage $i$ contradicts/refutes lineage $i+1$ (negation/frustration).

## 2. Temporal Ordering

- Braid words are constructed chronologically based on publication dates.
- The "Braid Word" represents the **Temporal Braiding of Scientific Consensus**.

## 3. Topological Audit Target: Structural Holes

- **Simplicability**: A "Sincere" citation network should simplify into a coherent "Stable Thread" (Identity word $1$ or minimal braid).
- **Persistent Frustration**: A braid word that **cannot be simplified** (Artin relations fail to reduce it) indicates:
  - **A Paradigm Gap**: A structural inability to reconcile two lineages.
  - **A Structural Defect**: Potential fraud or fundamental inconsistency (Topological Hole).

## 4. Implementation Steps

- **Stage P1**: Identify top-$n$ lineages in a specific field (e.g., Room-temp Superconductivity).
- **Stage P2**: Encode arXiv citation history as a Braid Word.
- **Stage P3**: Run the `BraidEngine` on the resulting word to calculate the **Distortion Score**.

---
*Status: MISSION_2_2_PRE-ALPHA*
