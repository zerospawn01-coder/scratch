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
- `governance_enforcer.py`: primary policy gate (`PolicyViolation`, `PolicyDecision`, `GovernanceEnforcer`)
- `exploration_governor.py`: exploration meta-gate — Phase P (`ExplorationPolicy`, `ExplorationStatus`, `ExplorationGovernor`)
- `gate.py`: backward-compatible wrapper — deprecated, use `GovernanceEnforcer` directly
- `run_loop.py`: single-run loop orchestration; emits `DecisionEvent` with hash chain
- `ledger.jsonl`: append-only `DecisionEvent` history
- `ledger.schema.json`: `DecisionEvent` schema (seq / run\_id / prev\_event\_hash / policy\_violations / event\_hash)

## Governance Layer Note

This demo kernel is a reduced public surface of a broader governance stack (Antigravity OS). `GovernanceEnforcer` mirrors the `GovernanceGate` / `GovernanceViolation` model of the TypeScript layer; `DecisionEvent` mirrors `LedgerEntry` from `rgo.ts`. > **「何を試すか」すら統治されるようになった**

`GovernanceEnforcer` (Phase O) と `ExplorationGovernor` (Phase P) は直列に合成されます：

```text
ExplorationGovernor.adjusted_min_improvement()  ← 探索自由度の制御
        ↓
GovernanceEnforcer.enforce()                    ← 安全性の絶対保証
        ↓
decision + policy_violations + exploration_status → DecisionEvent
```

`GovernanceEnforcer` が提供する fail-closed 安全保証は `ExplorationGovernor` によって上書きされません。探索の進化能力（liveness）と安全性（safety）は別レイヤーで独立に統治されます。

Phase R / S で観測と評価を分離して追加：

```text
DecisionEvent (raw ledger)
        -> override_observer.extract_episodes()      # Phase R: episode化
        -> override_analytics.analyze_episodes()     # Phase S: KPI + health + proposal
```

Phase S の health 判定は fail-closed ではなく warning 系の運用指標です。

- `HEALTHY`
- `AT_RISK`
- `EXHAUSTED`

Phase S は調整値を直接適用せず、`recommended_adjustments` を deterministic に返します。

- `increase_diversity_window`
- `increase_cooldown`
- `decrease_override_budget`
- `lower_base_min_improvement`
