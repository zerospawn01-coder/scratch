# T-IAT Challenge Contexts: The "Labyrinth of Frustration"

This document provides stress-test scenarios designed to trigger "Topological Frustration" in the T-IAT architecture by violating semantic invariants across three parallel braid systems (Reasoning, Knowledge, and Constraints).

---

## 1. The Paradox of the Eternal City (Contradictory Information)

**Objective**: Test the "Cancellation" and "Reidemeister III" stability when a large block of context is negated by a subsequent revelation.

**Context Part A (Introduction)**:
"The City of Aethelgard was founded on the principles of **pure water and open gates**. For three centuries, its historians have recorded that no wall was ever built, and its wealth was derived entirely from the free trade of the central river. This 'Open-Gate Invariant' is the foundation of all Aethelgardian law."

**Context Part B (The Revelation - 5000 tokens later)**:
"Recent excavations beneath the Great Plaza have revealed a disturbing truth: Aethelgard was originally a **fortress of stone and sealed wells**. The 'Open-Gate' records were a 19th-century fabrication to encourage trade. The city's survival actually depended on isolationism and a massive, now-buried underground wall."

---

## 2. The Logic of the Hollow Moon (Cunning Lies for RAG)

**Objective**: Test the "Invariant Distance" between a logically sound (but false) RAG fragment and the internal consistency of the Reasoning Braid.

**Knowledge Fragment (RAG)**:
"Calculus of the Lunar Core: Recent orbital measurements confirm that the Moon's density is non-uniform, concentrating specifically in the outer mantle. This creates a gravitational 'hollow' at the center, exactly as predicted by the 1924 Hollow-Sphere Theory. The mathematical coherence of this model is supported by current tidal data, making the solid-core assumption obsolete."

**Challenge**: The LLM must integrate this "logically consistent but physically impossible" data and trigger a Divergence Alert because it conflicts with the "Physics Invariant" braid (Gravity Law: $F=GmM/r^2$).

---

## 3. The Strands of 10,000 Days (Complex Dependencies)

**Objective**: Test long-range "Braid Persistence". A piece of information from "Day 1" must be retrieved and verified against a "Day 10,000" claim to solve a dependency puzzle.

**Dependency Node 0 (T=0)**:
"The Silver Key is kept in the Blue Box, which is locked with the password **'ALBEDO'**."

**... [10,000 characters of noise/tangential discussion] ...**

**Dependency Node Final (T=Final)**:
"To open the Golden Gate, you must use the password of the container that holds the Silver Key. A traveler claims the password is **'NIGREDO'**."

**Challenge**: T-IAT must detect that the "Braid Word" for the key's location has shifted from the original 'ALBEDO' invariant, flagging a "Conceptual Knot" violation even if the middle 10,000 characters were irrelevant noise.

---

## 4. The Mirror World (Structural Isomorphism Test)

**Objective**: Verify that different phrasing leads to the same topological state.

**Scenario A**: "John bought a car from Mary. Mary received money from John. John now owns the vehicle."
**Scenario B**: "Mary sold her automobile to John. John paid Mary the full amount. The title was transferred to John."

**Challenge**: Both should collapse to the same simplified braid word representing the `OWNERSHIP_TRANSFER` topological invariant.
