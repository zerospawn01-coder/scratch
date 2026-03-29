# Governed Evolution Demo Kernel v0.1

A minimal governed evolution loop where improvement alone is insufficient for adoption.

Improvement is necessary, but not sufficient.

This is not an optimization loop.
This is a governed evolution loop where improvement alone is insufficient for adoption.

## Quick Start

```bash
python run_loop.py
cat ledger.jsonl
cat program.md
```

Expected output example:

```text
attempts_logged=14, last_stop_check=stagnation
```

## What It Does

A candidate is mutated, evaluated, gated, and logged under explicit stop conditions.

## Minimal Loop

```text
Candidate
  -> Mutation
Candidates
  -> Evaluation (score + invariants)
Evaluated Candidates
  -> Gate (fail-closed)
Adopt / Reject
  -> Ledger (append-only)
Stop Check -> continue / halt
```

## Why It Is Not Just Optimization

Score = optimization axis.
Invariants = admissibility constraints.

The system separates "is it better?" from "is it allowable?".

## Core Rules

- Improvement can be required and still be rejected.
- Invariant violation forces rejection.
- All attempts are recorded in an append-only ledger.
- Stop conditions are fixed before execution.

## Files

- `program.md`: governance and decision policy
- `evolve.py`: candidate mutation
- `evaluate.py`: score and invariant evaluation
- `governance_enforcer.py`: primary policy gate — `PolicyViolation`, `PolicyDecision`, `GovernanceEnforcer` with lockdown
- `exploration_governor.py`: exploration meta-gate (Phase P) — `ExplorationPolicy`, `ExplorationStatus`, `ExplorationGovernor`; controls diversity, reject budget, stagnation override
- `gate.py`: backward-compatible wrapper over `GovernanceEnforcer` (deprecated)
- `run_loop.py`: loop execution, `DecisionEvent` ledger append, hash-chain management
- `ledger.jsonl`: append-only `DecisionEvent` log
- `ledger.schema.json`: `DecisionEvent` JSON schema (seq / prev\_event\_hash / event\_hash chain)

## Note

This demo kernel is a reduced public surface of a broader governance system.
