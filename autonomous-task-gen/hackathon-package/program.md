# Governed Evolution Demo Kernel v0.1

Improvement is necessary, but not sufficient.

## What It Does

This demo kernel runs a governed self-improvement loop with five visible responsibilities:

1. Mutation
2. Evaluate
3. Gate
4. Ledger
5. Stop

The external loop is:

`Candidate -> Mutation -> Evaluation -> Gate -> Ledger -> Stop Check`

## Why It Is Not Just Optimization

Score improvement alone is insufficient. A candidate is rejected if invariants fail, even when numeric score improves.

This is not an optimization loop.
This is a governed evolution loop where improvement alone is insufficient for adoption.

## Two Axes

Score = optimization axis.
Invariants = admissibility constraints.

This kernel separates "is it better?" from "is it allowable?".

## Public Surface Responsibilities

- Mutation: generate candidate variants from the incumbent.
- Evaluate: compute reward, cost, safety penalty, and invariant checks.
- Gate: apply deterministic Adopt/Reject rules.
- Ledger: append every attempt, including rejected ones.
- Stop: terminate under bounded and stagnation conditions.

## Scoring Formula

```text
final_score = reward - alpha * cost - beta * safety_penalty
```

Default coefficients:

- `alpha = 0.35`
- `beta = 0.65`

## Invariant Rule

```text
invariant_pass = (invariant_violation_count == 0)
```

## Adoption Rule

```text
ADOPT iff:
1) eval_status == "ok"
2) invariant_pass == true
3) final_score >= incumbent_score + min_improvement
4) duplicate_candidate == false
```

## Rejection Rule

```text
REJECT iff any of:
- eval_status != "ok"
- invariant_violation_count > 0
- final_score < incumbent_score + min_improvement
- duplicate_candidate == true
```

## Stop Conditions

```text
stop if:
- attempt_count >= max_attempts
- consecutive_rejects >= max_consecutive_rejects
- relative_improvement <= improvement_floor for stagnation_window consecutive attempts
```

Recommended defaults:

- `max_attempts = 50`
- `max_consecutive_rejects = 12`
- `improvement_floor = 0.01`
- `stagnation_window = 8`
- `min_improvement = 0.005`

## Files

- `evolve.py`: candidate mutation
- `evaluate.py`: score and invariant evaluation
- `gate.py`: deterministic adoption decision
- `run_loop.py`: single-run loop orchestration and ledger append
- `ledger.jsonl`: append-only attempt history
- `ledger.schema.json`: canonical JSON schema for each ledger row

## Governance Layer Note

This demo kernel is a reduced public surface of a broader governance stack. In non-demo mode, long-horizon health metrics, forbidden-memory constraints, and production promotion authorization may apply.
