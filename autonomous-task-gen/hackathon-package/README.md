<<<<<<< HEAD
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
- `override_observer.py`: Phase R observability layer — extracts override episodes from DecisionEvent rows
- `override_analytics.py`: Phase S analytics layer — computes KPI, warning health status, and deterministic feedback proposals
- `adaptive_governance.py`: Phase T proposal layer — evaluates deterministic next-run tuning candidates (proposal-only)
- `gate.py`: backward-compatible wrapper over `GovernanceEnforcer` (deprecated)
- `run_loop.py`: loop execution, `DecisionEvent` ledger append, hash-chain management
- `ledger.jsonl`: append-only `DecisionEvent` log
- `ledger.schema.json`: `DecisionEvent` JSON schema (seq / prev\_event\_hash / event\_hash chain)

## Governance Evolution Layers

- Phase O: governed search safety (`GovernanceEnforcer`)
- Phase P: exploration liveness governance (`ExplorationGovernor`)
- Phase Q: override budget + escape proof metrics
- Phase R: override episode observability (`OverrideEpisode`)
- Phase S: episode analytics + health judgment + feedback proposal (`override_analytics.py`)
- Phase T: self-tuning planning (`adaptive_governance.py`) — candidate simulation/selection for next run, no auto-apply

Phase S/T are proposal-only by design: they do not auto-apply runtime policy changes.

Phase T also supports append-only audit output for plan records:

- `build_plan_from_ledger(ledger_path)`
- `report_plan_to_jsonl(plan, adaptive_plan_report_path, source_ledger)`

## Note

This demo kernel is a reduced public surface of a broader governance system.
=======
# Autonomous Task Gen Hackathon Package

This directory is a standalone package candidate and should be treated as the
seed of a future dedicated repository rather than a permanent `scratch`
subdirectory.

## Current Role

- Governance-heavy autonomous task generation package
- Includes promotion, rollback, throughput, alerting, and playbook logic
- Organized around TypeScript source under `src/`

## Source Layout

- `src/services/`
  - core service and orchestration logic
- `src/tests/`
  - test surface for the package
- `src/types/`
  - shared contracts and domain types

## What Should Move With This Package

Keep when splitting to a dedicated repo:

- `src/services/`
- `src/tests/`
- `src/types/`
- a future package manifest
- a future build/test configuration

Do not treat these as durable source assets:

- `dist/`
- `node_modules/`
- `out*.txt`
- `test_output.txt`

## Split Guidance

Before promoting this package into its own repository:

1. add a real package manifest (`package.json`)
2. add a reproducible install/build/test entrypoint
3. confirm which generated outputs should remain local-only
4. move only source, tests, and intentional documentation into the new repo

>>>>>>> origin/phase14-readiness-gate
