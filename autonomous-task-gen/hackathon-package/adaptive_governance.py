"""
adaptive_governance.py — Phase T: Adaptive Governance (Proposal-Only)

Builds a deterministic self-tuning planner on top of Phase S analytics.
The planner does NOT mutate live runtime policy. It proposes next-run settings
and keeps apply_now=False for fail-safe operation.

Flow:
    Override analytics report (Phase S)
        -> deterministic tuning candidates
        -> deterministic simulation score
        -> selected next-run proposal

This module is intentionally advisory and side-effect free.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, List

from exploration_governor import ExplorationPolicy  # type: ignore[import-not-found]
from override_analytics import AnalyticsThresholds, ExplorationAnalyticsReport  # type: ignore[import-not-found]


DEFAULT_BASE_MIN_IMPROVEMENT = 0.005


@dataclass(frozen=True)
class TuningCandidate:
    """One deterministic next-run policy candidate."""

    name: str
    policy: ExplorationPolicy
    base_min_improvement: float
    score: float

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "policy": self.policy.to_dict(),
            "base_min_improvement": self.base_min_improvement,
            "score": self.score,
        }


@dataclass(frozen=True)
class AdaptivePlan:
    """Final proposal bundle from Phase T."""

    health_status: str
    apply_now: bool
    selected_candidate: TuningCandidate
    evaluated_candidates: List[TuningCandidate]
    rationale: List[str]

    def to_dict(self) -> Dict:
        return {
            "health_status": self.health_status,
            "apply_now": self.apply_now,
            "selected_candidate": self.selected_candidate.to_dict(),
            "evaluated_candidates": [c.to_dict() for c in self.evaluated_candidates],
            "rationale": self.rationale,
        }


def _unique_ordered(values: List[str]) -> List[str]:
    out: List[str] = []
    seen = set()
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        out.append(value)
    return out


def _apply_adjustments(
    base_policy: ExplorationPolicy,
    base_min_improvement: float,
    adjustments: List[str],
) -> tuple[ExplorationPolicy, float]:
    policy = ExplorationPolicy(
        max_reject_ratio=base_policy.max_reject_ratio,
        min_diversity_score=base_policy.min_diversity_score,
        stagnation_tolerance=base_policy.stagnation_tolerance,
        override_budget=base_policy.override_budget,
        window_size=base_policy.window_size,
    )
    next_base_min = base_min_improvement

    for adj in adjustments:
        if adj == "increase_diversity_window":
            policy.window_size = min(100, policy.window_size + 2)
            policy.min_diversity_score = round(min(1.0, policy.min_diversity_score + 0.05), 4)
        elif adj == "increase_cooldown":
            policy.stagnation_tolerance = min(100, policy.stagnation_tolerance + 1)
        elif adj == "decrease_override_budget":
            policy.override_budget = max(1, policy.override_budget - 1)
        elif adj == "lower_base_min_improvement":
            next_base_min = round(max(0.0, next_base_min - 0.001), 6)

    return policy, next_base_min


def _candidate_score(
    report: ExplorationAnalyticsReport,
    base_policy: ExplorationPolicy,
    base_min_improvement: float,
    policy: ExplorationPolicy,
    candidate_base_min: float,
) -> float:
    """Deterministic heuristic score for simulation-only ranking."""
    utility = 0.0

    if report.improving_escape_rate < 0.35 and policy.window_size > base_policy.window_size:
        utility += 1.0

    if report.budget_exhaust_rate > 0.50 and policy.override_budget < base_policy.override_budget:
        utility += 1.0

    if report.budget_exhaust_rate > 0.50 and policy.stagnation_tolerance > base_policy.stagnation_tolerance:
        utility += 0.5

    if report.override_frequency > 0.12 and candidate_base_min < base_min_improvement:
        utility += 0.75

    # Keep changes conservative: penalize large deltas.
    penalty = 0.0
    penalty += 0.05 * abs(policy.window_size - base_policy.window_size)
    penalty += 0.10 * abs(policy.override_budget - base_policy.override_budget)
    penalty += 0.05 * abs(policy.stagnation_tolerance - base_policy.stagnation_tolerance)
    penalty += 0.20 * abs(policy.min_diversity_score - base_policy.min_diversity_score)
    penalty += 50.0 * abs(candidate_base_min - base_min_improvement)

    return round(utility - penalty, 4)


def _build_candidates(
    report: ExplorationAnalyticsReport,
    base_policy: ExplorationPolicy,
    base_min_improvement: float,
) -> List[TuningCandidate]:
    adjustments = _unique_ordered(report.recommended_adjustments)
    candidate_specs: List[tuple[str, List[str]]] = [("baseline", [])]

    for adj in adjustments:
        candidate_specs.append((f"single::{adj}", [adj]))

    if adjustments:
        candidate_specs.append(("combined::all", adjustments))

    candidates: List[TuningCandidate] = []
    for name, adjs in candidate_specs:
        policy, candidate_base_min = _apply_adjustments(base_policy, base_min_improvement, adjs)
        score = _candidate_score(
            report=report,
            base_policy=base_policy,
            base_min_improvement=base_min_improvement,
            policy=policy,
            candidate_base_min=candidate_base_min,
        )
        candidates.append(TuningCandidate(
            name=name,
            policy=policy,
            base_min_improvement=candidate_base_min,
            score=score,
        ))

    # Stable order by score desc, then by name for determinism.
    candidates.sort(key=lambda c: (-c.score, c.name))
    return candidates


def build_adaptive_plan(
    report: ExplorationAnalyticsReport,
    current_policy: ExplorationPolicy = ExplorationPolicy(),
    base_min_improvement: float = DEFAULT_BASE_MIN_IMPROVEMENT,
    _thresholds: AnalyticsThresholds = AnalyticsThresholds(),
) -> AdaptivePlan:
    """
    Build Phase T proposal from Phase S report.

    apply_now is always False by design (proposal-only safety posture).
    """
    evaluated = _build_candidates(
        report=report,
        base_policy=current_policy,
        base_min_improvement=base_min_improvement,
    )
    selected = evaluated[0]

    rationale: List[str] = [
        "Phase T runs in proposal-only mode; runtime policy is not auto-mutated.",
        f"Selected candidate by deterministic ranking: {selected.name} (score={selected.score}).",
    ]

    if report.health_status == "EXHAUSTED":
        rationale.append("Health is EXHAUSTED: escalate candidate review before next run.")
    elif report.health_status == "AT_RISK":
        rationale.append("Health is AT_RISK: use selected candidate as next-run draft.")
    else:
        rationale.append("Health is HEALTHY: baseline may remain acceptable.")

    return AdaptivePlan(
        health_status=report.health_status,
        apply_now=False,
        selected_candidate=selected,
        evaluated_candidates=evaluated,
        rationale=rationale,
    )
