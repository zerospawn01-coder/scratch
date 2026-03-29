"""
exploration_governor.py — Phase P + Q: Exploration Governance

Meta-governor that monitors exploration health and prevents:
    - Premature convergence (diversity collapse)
    - Over-conservative rejection (reject ratio too high / exploration exhausted)
    - Permanent stagnation without recovery attempt
    - Override session running unbounded (Phase Q: override budget cap)

Layering relative to GovernanceEnforcer:
    GovernanceEnforcer  — hard gate    (safety, invariants, lockdown)
    ExplorationGovernor — soft meta    (diversity, budget, stagnation recovery, override cap)

GovernanceEnforcer provides the fail-closed safety guarantee.
ExplorationGovernor provides the exploration-liveness guarantee.

Neither overrides the other; they compose:
    effective_min = governor.adjusted_min_improvement(base_min)
    decision      = enforcer.enforce(..., min_improvement=effective_min)
    governor.record(decision, candidate_hash, improving)
    health_viols  = governor.health_violations()   # WARNING only (call post-record)

Warning-level violations (EXPLORATION_EXHAUSTED, DIVERSITY_COLLAPSE,
OVERRIDE_BUDGET_EXCEEDED) appear in policy_violations for observability but do
NOT cause REJECT on their own.  Hard stops from the enforcer are never overridden.

Phase Q additions:
    override_budget       — max attempts per override episode
    escape proof metrics  — escape_adopt_count / escape_novel_count per episode
    OVERRIDE_BUDGET_EXCEEDED WARNING — fired when episode exhausts its budget
    stagnation_count reset on budget exhaustion to prevent immediate re-activation
"""
from __future__ import annotations

from collections import deque
from dataclasses import asdict, dataclass
from typing import Deque, Dict, List, Optional

from governance_enforcer import PolicyViolation  # type: ignore[import-not-found]


@dataclass
class ExplorationPolicy:
    """Configurable exploration health parameters."""

    max_reject_ratio: float = 0.85
    """Sliding-window reject ratio above which exploration is flagged EXPLORATION_EXHAUSTED."""

    min_diversity_score: float = 0.30
    """Minimum unique-candidate ratio in window. Below this → DIVERSITY_COLLAPSE."""

    stagnation_tolerance: int = 8
    """Consecutive non-improving attempts before STAGNATION_OVERRIDE activates."""

    override_budget: int = 5
    """Max attempts allowed per override episode. Budget exhaustion fires OVERRIDE_BUDGET_EXCEEDED
    (WARNING) and deactivates the override to prevent unbounded relaxation."""

    window_size: int = 10
    """Sliding window size for ratio and diversity measurement."""

    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass(frozen=True)
class ExplorationStatus:
    """Point-in-time snapshot of exploration health after recording one attempt."""

    reject_ratio: float
    diversity_score: float
    stagnation_count: int
    override_active: bool
    override_reason: Optional[str]
    # Phase Q: override episode budget and escape proof metrics
    override_attempts_used: int
    override_budget: int
    escape_adopt_count: int
    escape_novel_count: int

    def to_dict(self) -> Dict:
        return {
            "reject_ratio": self.reject_ratio,
            "diversity_score": self.diversity_score,
            "stagnation_count": self.stagnation_count,
            "override_active": self.override_active,
            "override_reason": self.override_reason,
            "override_attempts_used": self.override_attempts_used,
            "override_budget": self.override_budget,
            "escape_adopt_count": self.escape_adopt_count,
            "escape_novel_count": self.escape_novel_count,
        }


class ExplorationGovernor:
    """
    Sliding-window exploration health monitor.

    Activation rules (in priority order):
      STAGNATION_OVERRIDE   — stagnation_count >= stagnation_tolerance
      EXPLORATION_EXHAUSTED — reject_ratio     >  max_reject_ratio

    When override_active is True, adjusted_min_improvement() returns 0.0 to
    temporarily relax the improvement gate and let the search escape the basin.
        The override deactivates when: (a) a genuinely improving attempt is recorded,
        or (b) the episode consumes override_budget attempts (Phase Q).
    """

    def __init__(self, policy: Optional[ExplorationPolicy] = None) -> None:
        self._policy: ExplorationPolicy = policy or ExplorationPolicy()
        self._decision_window: Deque[str] = deque(maxlen=self._policy.window_size)
        self._hash_window: Deque[str] = deque(maxlen=self._policy.window_size)
        self._stagnation_count: int = 0
        self._override_active: bool = False
        self._override_reason: Optional[str] = None
        # Phase Q: per-episode tracking
        self._override_attempt_count: int = 0
        self._escape_adopt_count: int = 0
        self._escape_novel_count: int = 0
        self._override_hashes: set = set()
        self._budget_exceeded: bool = False
        self._budget_cooldown_steps: int = 0

    @property
    def policy(self) -> ExplorationPolicy:
        return self._policy

    @property
    def is_override_active(self) -> bool:
        return self._override_active

    def record(self, decision: str, candidate_hash: str, improving: bool) -> None:
        """
        Record the outcome of one governed attempt.

        :param decision:       "ADOPT" or "REJECT"
        :param candidate_hash: sha256:... hash of the candidate
        :param improving:      True if rel_improvement > improvement_floor
        """
        self._budget_exceeded = False  # clear previous episode's flag
        self._decision_window.append(decision)
        self._hash_window.append(candidate_hash)

        if not improving:
            self._stagnation_count += 1
        else:
            self._stagnation_count = 0

        was_active = self._override_active
        self._update_override()

        # If override ended due to improving attempt, count this as an escape success.
        if was_active and not self._override_active and improving:
            self._escape_adopt_count += 1
            if candidate_hash not in self._override_hashes:
                self._override_hashes.add(candidate_hash)
                self._escape_novel_count += 1

        # Phase Q: if override just activated, reset episode metrics
        if not was_active and self._override_active:
            self._override_attempt_count = 0
            self._escape_adopt_count = 0
            self._escape_novel_count = 0
            self._override_hashes = set()

        # Track escape metrics while override is active
        if self._override_active:
            self._override_attempt_count += 1
            if decision == "ADOPT":
                self._escape_adopt_count += 1
            if candidate_hash not in self._override_hashes:
                self._override_hashes.add(candidate_hash)
                self._escape_novel_count += 1

        # Phase Q: budget exhaustion — force deactivate and reset stagnation
        if self._override_active and self._override_attempt_count >= self._policy.override_budget:
            self._override_active = False
            self._override_reason = None
            self._stagnation_count = 0  # cooldown: prevent immediate re-activation
            self._budget_exceeded = True
            self._budget_cooldown_steps = 1

    def _update_override(self) -> None:
        if self._budget_cooldown_steps > 0:
            self._budget_cooldown_steps -= 1
            self._override_active = False
            self._override_reason = None
            return
        if self._stagnation_count >= self._policy.stagnation_tolerance:
            self._override_active = True
            self._override_reason = "STAGNATION_OVERRIDE"
        elif self._reject_ratio() > self._policy.max_reject_ratio:
            self._override_active = True
            self._override_reason = "EXPLORATION_EXHAUSTED"
        else:
            self._override_active = False
            self._override_reason = None

    def _reject_ratio(self) -> float:
        if not self._decision_window:
            return 0.0
        return sum(1 for d in self._decision_window if d == "REJECT") / len(self._decision_window)

    def _diversity_score(self) -> float:
        if not self._hash_window:
            return 1.0
        return len(set(self._hash_window)) / len(self._hash_window)

    def current_status(self) -> ExplorationStatus:
        return ExplorationStatus(
            reject_ratio=round(self._reject_ratio(), 4),
            diversity_score=round(self._diversity_score(), 4),
            stagnation_count=self._stagnation_count,
            override_active=self._override_active,
            override_reason=self._override_reason,
            override_attempts_used=self._override_attempt_count,
            override_budget=self._policy.override_budget,
            escape_adopt_count=self._escape_adopt_count,
            escape_novel_count=self._escape_novel_count,
        )

    def adjusted_min_improvement(self, base_min: float) -> float:
        """
        Return 0.0 when override is active (relax improvement gate).
        The enforcer may still reject for other reasons (invariants, duplicates, lockdown).
        """
        return 0.0 if self._override_active else base_min

    def health_violations(self) -> List[PolicyViolation]:
        """
        Return WARNING-level PolicyViolations for degraded exploration health.
        Non-blocking: appended to policy_violations for observability only.
        """
        violations: List[PolicyViolation] = []
        ratio = self._reject_ratio()
        diversity = self._diversity_score()
        w = len(self._decision_window)

        if ratio > self._policy.max_reject_ratio:
            violations.append(PolicyViolation(
                code="EXPLORATION_EXHAUSTED",
                severity="WARNING",
                message=(
                    f"reject_ratio {ratio:.2f} > max_reject_ratio "
                    f"{self._policy.max_reject_ratio:.2f} "
                    f"(window={w})"
                ),
            ))

        if diversity < self._policy.min_diversity_score:
            violations.append(PolicyViolation(
                code="DIVERSITY_COLLAPSE",
                severity="WARNING",
                message=(
                    f"diversity_score {diversity:.2f} < min_diversity_score "
                    f"{self._policy.min_diversity_score:.2f} "
                    f"(window={w})"
                ),
            ))

        # Phase Q: override budget exhausted this step
        if self._budget_exceeded:
            violations.append(PolicyViolation(
                code="OVERRIDE_BUDGET_EXCEEDED",
                severity="WARNING",
                message=(
                    f"STAGNATION_OVERRIDE exhausted {self._policy.override_budget}-attempt "
                    f"budget (escape_adopt={self._escape_adopt_count}, "
                    f"escape_novel={self._escape_novel_count}). "
                    f"Override deactivated; stagnation_count reset."
                ),
            ))

        return violations
