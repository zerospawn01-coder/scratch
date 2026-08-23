"""
override_analytics.py — Phase S: Exploration Analytics / Control Feedback Proposal

Builds a deterministic analytics layer on top of Phase R OverrideEpisode extraction.
This module is intentionally read-only: it returns KPI summaries, health judgment,
and recommended adjustments, but does NOT mutate runtime policy directly.

Pipeline:
    DecisionEvent rows -> OverrideEpisode (Phase R) -> Phase S analytics report

Returned report fields:
    - override_frequency
    - avg_episode_length
    - improving_escape_rate
    - budget_exhaust_rate
    - health_status          (HEALTHY / AT_RISK / EXHAUSTED)
    - recommended_adjustments
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List

from override_observer import OverrideEpisode, load_episodes_from_ledger  # type: ignore[import-not-found]


@dataclass(frozen=True)
class AnalyticsThresholds:
    """Deterministic threshold set for health classification and recommendations."""

    min_improving_escape_rate: float = 0.35
    max_budget_exhaust_rate: float = 0.50
    max_override_frequency: float = 0.12


@dataclass
class ExplorationAnalyticsReport:
    """Serializable analytics report for one episode set (or ledger slice)."""

    episode_count: int
    attempt_span: int
    override_frequency: float
    avg_episode_length: float
    improving_escape_rate: float
    budget_exhaust_rate: float
    passive_deactivate_rate: float
    run_truncated_rate: float
    health_status: str
    recommended_adjustments: List[str]

    def to_dict(self) -> Dict:
        return asdict(self)


def _safe_rate(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return round(numerator / denominator, 4)


def _attempt_span(episodes: List[OverrideEpisode]) -> int:
    if not episodes:
        return 0
    start = min(ep.start_seq for ep in episodes)
    end = max(ep.end_seq for ep in episodes)
    return max(0, end - start + 1)


def _health_status(
    improving_escape_rate: float,
    budget_exhaust_rate: float,
    override_frequency: float,
    thresholds: AnalyticsThresholds,
) -> str:
    """Warning-only operational status (never a hard safety block)."""
    if (
        improving_escape_rate < thresholds.min_improving_escape_rate
        and budget_exhaust_rate > thresholds.max_budget_exhaust_rate
    ):
        return "EXHAUSTED"

    if (
        improving_escape_rate < thresholds.min_improving_escape_rate
        or budget_exhaust_rate > thresholds.max_budget_exhaust_rate
        or override_frequency > thresholds.max_override_frequency
    ):
        return "AT_RISK"

    return "HEALTHY"


def _recommended_adjustments(
    improving_escape_rate: float,
    budget_exhaust_rate: float,
    override_frequency: float,
    thresholds: AnalyticsThresholds,
) -> List[str]:
    """
    Deterministic proposal rules in fixed order.

    This function proposes adjustments only; it never applies them.
    """
    adjustments: List[str] = []

    if improving_escape_rate < thresholds.min_improving_escape_rate:
        adjustments.append("increase_diversity_window")

    if budget_exhaust_rate > thresholds.max_budget_exhaust_rate:
        adjustments.append("increase_cooldown")
        if budget_exhaust_rate > (thresholds.max_budget_exhaust_rate + 0.20):
            adjustments.append("decrease_override_budget")

    if override_frequency > thresholds.max_override_frequency:
        adjustments.append("lower_base_min_improvement")

    return adjustments


def analyze_episodes(
    episodes: List[OverrideEpisode],
    thresholds: AnalyticsThresholds = AnalyticsThresholds(),
) -> ExplorationAnalyticsReport:
    """
    Compute deterministic KPI + health + recommendation report from episodes.
    """
    episode_count = len(episodes)
    span = _attempt_span(episodes)

    if episode_count == 0:
        return ExplorationAnalyticsReport(
            episode_count=0,
            attempt_span=span,
            override_frequency=0.0,
            avg_episode_length=0.0,
            improving_escape_rate=0.0,
            budget_exhaust_rate=0.0,
            passive_deactivate_rate=0.0,
            run_truncated_rate=0.0,
            health_status="HEALTHY",
            recommended_adjustments=[],
        )

    improving_escape_count = sum(1 for ep in episodes if ep.outcome == "improving_escape")
    budget_exhaust_count = sum(1 for ep in episodes if ep.outcome == "budget_exhausted")
    passive_count = sum(1 for ep in episodes if ep.outcome == "passive_deactivate")
    truncated_count = sum(1 for ep in episodes if ep.outcome == "run_truncated")

    avg_length = round(
        sum((ep.end_seq - ep.start_seq + 1) for ep in episodes) / episode_count,
        4,
    )
    override_frequency = _safe_rate(episode_count, span if span > 0 else 1)
    improving_escape_rate = _safe_rate(improving_escape_count, episode_count)
    budget_exhaust_rate = _safe_rate(budget_exhaust_count, episode_count)
    passive_rate = _safe_rate(passive_count, episode_count)
    truncated_rate = _safe_rate(truncated_count, episode_count)

    health = _health_status(
        improving_escape_rate=improving_escape_rate,
        budget_exhaust_rate=budget_exhaust_rate,
        override_frequency=override_frequency,
        thresholds=thresholds,
    )
    adjustments = _recommended_adjustments(
        improving_escape_rate=improving_escape_rate,
        budget_exhaust_rate=budget_exhaust_rate,
        override_frequency=override_frequency,
        thresholds=thresholds,
    )

    return ExplorationAnalyticsReport(
        episode_count=episode_count,
        attempt_span=span,
        override_frequency=override_frequency,
        avg_episode_length=avg_length,
        improving_escape_rate=improving_escape_rate,
        budget_exhaust_rate=budget_exhaust_rate,
        passive_deactivate_rate=passive_rate,
        run_truncated_rate=truncated_rate,
        health_status=health,
        recommended_adjustments=adjustments,
    )


def analyze_ledger(
    path: Path,
    thresholds: AnalyticsThresholds = AnalyticsThresholds(),
) -> ExplorationAnalyticsReport:
    """Convenience API: load episodes from ledger then compute analytics report."""
    episodes = load_episodes_from_ledger(path)
    return analyze_episodes(episodes, thresholds=thresholds)
