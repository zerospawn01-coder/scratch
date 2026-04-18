"""gate.py — Deprecated backward-compatible wrapper.

Use governance_enforcer.GovernanceEnforcer directly for new code.
This module exists solely to keep existing callers (e.g. the operational test
suite) working while the loop migrates to GovernanceEnforcer + DecisionEvent.

The wrapper creates a *fresh* GovernanceEnforcer per call so each invocation
is fully stateless, replicating the original gate_decision behaviour exactly.
"""
from __future__ import annotations

from typing import Dict, Tuple

from governance_enforcer import GovernanceEnforcer  # type: ignore[import-not-found]


def gate_decision(
    evaluation: Dict,
    incumbent_score: float,
    min_improvement: float,
    duplicate_candidate: bool,
) -> Tuple[str, str]:
    """Stateless wrapper over GovernanceEnforcer. Creates a fresh enforcer per call."""
    enforcer = GovernanceEnforcer()
    result = enforcer.enforce(
        candidate_hash="",
        evaluation=evaluation,
        incumbent_score=incumbent_score,
        min_improvement=min_improvement,
        duplicate_candidate=duplicate_candidate,
    )
    return result.decision, result.decision_reason
