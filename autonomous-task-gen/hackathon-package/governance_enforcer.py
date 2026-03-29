"""
governance_enforcer.py — Phase O: Governed Search Loop

Primary policy gate for governed evolution.
Replaces gate.py as the authoritative enforcement layer.

Mirrors the GovernanceGate / GovernanceViolation structure of the TypeScript
Antigravity OS (src/services/GovernanceGate.ts) on the Python loop side, making
the exploration loop a first-class governed subsystem rather than an external tool.

Decision taxonomy:
  ADOPT   — score improved and all policy checks pass
  REJECT  — one or more PolicyViolation(s) with CRITICAL or FATAL severity

Violation codes (in priority order):
  SYSTEM_LOCKDOWN         FATAL    — enforcer entered lockdown after repeated fatals
  EVAL_ERROR              FATAL    — evaluation returned non-ok status
  INVARIANT_VIOLATION     FATAL    — invariant_violation_count > 0
  DUPLICATE_CANDIDATE     CRITICAL — candidate hash already in ledger
  INSUFFICIENT_IMPROVEMENT CRITICAL — score < incumbent + min_improvement
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List


@dataclass(frozen=True)
class PolicyViolation:
    code: str
    severity: str  # "WARNING" | "CRITICAL" | "FATAL"
    message: str

    def to_dict(self) -> Dict:
        return {"code": self.code, "severity": self.severity, "message": self.message}


@dataclass(frozen=True)
class PolicyDecision:
    decision: str  # "ADOPT" | "REJECT"
    violations: List[PolicyViolation]
    decision_reason: str

    @property
    def is_fatal(self) -> bool:
        return any(v.severity == "FATAL" for v in self.violations)


class GovernanceEnforcer:
    """
    Fail-closed policy gate for governed evolution.

    Converts raw evaluation output into PolicyViolation objects and produces a
    deterministic ADOPT / REJECT decision.  Mirrors the lockdown mechanic of
    GovernanceGate.ts: after LOCKDOWN_THRESHOLD consecutive FATAL violations the
    enforcer enters lockdown and rejects every subsequent candidate regardless of
    score.

    Equivalent mapping to TypeScript governance layer:
      GovernanceEnforcer.enforce()   ≈ GovernanceGate.evaluatePostExecution()
      PolicyViolation                ≈ GovernanceViolation
      PolicyDecision.decision        ≈ GovernanceGateResult.status (PASS→ADOPT, FAIL→REJECT)
      INVARIANT_VIOLATION            ≈ INVALID_THRESHOLD / DATA_LEAK_DETECTED (severity: FATAL)
    """

    LOCKDOWN_THRESHOLD: int = 5

    def __init__(self) -> None:
        self._fatal_streak: int = 0
        self._locked_down: bool = False

    @property
    def is_locked_down(self) -> bool:
        return self._locked_down

    def reset_lockdown(self) -> None:
        self._fatal_streak = 0
        self._locked_down = False

    def enforce(
        self,
        candidate_hash: str,
        evaluation: Dict,
        incumbent_score: float,
        min_improvement: float,
        duplicate_candidate: bool,
    ) -> PolicyDecision:
        violations: List[PolicyViolation] = []

        # --- Lockdown guard (always highest priority) ---
        if self._locked_down:
            violations.append(PolicyViolation(
                code="SYSTEM_LOCKDOWN",
                severity="FATAL",
                message="GovernanceEnforcer is in lockdown after repeated fatal violations.",
            ))
            return PolicyDecision(
                decision="REJECT",
                violations=violations,
                decision_reason="rejected_system_lockdown",
            )

        # --- Evaluation error ---
        if evaluation.get("eval_status") != "ok":
            violations.append(PolicyViolation(
                code="EVAL_ERROR",
                severity="FATAL",
                message="Evaluation returned non-ok status.",
            ))

        # --- Invariant violations → Policy violations (FATAL) ---
        inv_count = int(evaluation.get("invariant_violation_count", 0))
        if inv_count > 0:
            violations.append(PolicyViolation(
                code="INVARIANT_VIOLATION",
                severity="FATAL",
                message=f"{inv_count} invariant(s) violated.",
            ))

        # --- Duplicate candidate ---
        if duplicate_candidate:
            violations.append(PolicyViolation(
                code="DUPLICATE_CANDIDATE",
                severity="CRITICAL",
                message=f"Candidate {candidate_hash} already exists in ledger.",
            ))

        # --- Insufficient improvement ---
        candidate_score = float(evaluation.get("final_score", -1e9))
        if candidate_score < incumbent_score + min_improvement:
            violations.append(PolicyViolation(
                code="INSUFFICIENT_IMPROVEMENT",
                severity="CRITICAL",
                message=(
                    f"score {candidate_score:.6f} < "
                    f"incumbent {incumbent_score:.6f} + min_improvement {min_improvement:.6f}"
                ),
            ))

        # --- Gate decision ---
        has_blocking = any(v.severity in ("FATAL", "CRITICAL") for v in violations)
        if has_blocking:
            if any(v.severity == "FATAL" for v in violations):
                self._fatal_streak += 1
                if self._fatal_streak >= self.LOCKDOWN_THRESHOLD:
                    self._locked_down = True
            return PolicyDecision(
                decision="REJECT",
                violations=violations,
                decision_reason=_reason_from_violations(violations),
            )

        self._fatal_streak = 0
        return PolicyDecision(
            decision="ADOPT",
            violations=violations,
            decision_reason="adopted_score_improved_and_invariants_passed",
        )


def _reason_from_violations(violations: List[PolicyViolation]) -> str:
    fatal_codes = {v.code for v in violations if v.severity == "FATAL"}
    if "SYSTEM_LOCKDOWN" in fatal_codes:
        return "rejected_system_lockdown"
    if "EVAL_ERROR" in fatal_codes:
        return "rejected_evaluation_error"
    if "INVARIANT_VIOLATION" in fatal_codes:
        return "rejected_invariant_violation"
    critical_codes = {v.code for v in violations if v.severity == "CRITICAL"}
    if "DUPLICATE_CANDIDATE" in critical_codes:
        return "rejected_duplicate_candidate"
    if "INSUFFICIENT_IMPROVEMENT" in critical_codes:
        return "rejected_due_to_no_improvement_despite_valid_invariants"
    return "rejected_policy_violation"
