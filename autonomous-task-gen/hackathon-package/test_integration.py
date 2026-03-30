"""Operational test suite for Phase O + P + Q + R integrated governance loop."""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, ".")

import run_loop as rl
from evaluate import evaluate_candidate  # type: ignore[import-not-found]
from exploration_governor import ExplorationGovernor, ExplorationPolicy  # type: ignore[import-not-found]
from gate import gate_decision  # type: ignore[import-not-found]
from governance_enforcer import GovernanceEnforcer  # type: ignore[import-not-found]
from override_observer import OverrideEpisode, extract_episodes  # type: ignore[import-not-found]
from override_analytics import (  # type: ignore[import-not-found]
    AnalyticsThresholds,
    analyze_episodes,
)

NULL_HASH = "sha256:" + "0" * 64


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def load_required_keys(schema_path: Path):
    s = json.load(open(schema_path, encoding="utf-8"))
    return set(s["required"])


required_keys = load_required_keys(Path("ledger.schema.json"))

with tempfile.TemporaryDirectory() as td:

    # 1. Default run: stagnation stop
    rl.LEDGER_PATH = Path(td) / "ledger.jsonl"
    rows = rl.run_loop()
    require(len(rows) > 0, "no rows")
    require(rows[-1]["stop_check"] == "stagnation", f"wrong stop: {rows[-1]['stop_check']}")
    print(f"[1] stagnation stop OK (attempts={len(rows)})")

    # 2. Schema key check
    for i, row in enumerate(rows, 1):
        diff = set(row.keys()).symmetric_difference(required_keys)
        require(not diff, f"row#{i} key mismatch: {diff}")
    print("[2] schema key check OK")

    # 3. Hash chain integrity
    prev = NULL_HASH
    for i, row in enumerate(rows, 1):
        require(row["prev_event_hash"] == prev, f"row#{i} chain broken")
        prev = row["event_hash"]
    print("[3] hash chain OK")

    # 4. run_id consistent within one run
    run_ids = {r["run_id"] for r in rows}
    require(len(run_ids) == 1, f"multiple run_ids: {run_ids}")
    print("[4] run_id consistent OK")

    # 5. seq monotonic 1-indexed
    seqs = [r["seq"] for r in rows]
    require(seqs == list(range(1, len(rows) + 1)), "seq not monotonic")
    print("[5] seq monotonic OK")

    # 6. max_attempts stop
    rl.LEDGER_PATH = Path(td) / "max.jsonl"
    rows_max = rl.run_loop(max_attempts=3, max_consecutive_rejects=99, stagnation_window=99)
    require(len(rows_max) == 3, f"max_attempts: {len(rows_max)}")
    require(rows_max[-1]["stop_check"] == "max_attempts", rows_max[-1]["stop_check"])
    print("[6] max_attempts OK")

    # 7. max_consecutive_rejects stop
    rl.LEDGER_PATH = Path(td) / "rej.jsonl"
    rows_rej = rl.run_loop(max_attempts=99, max_consecutive_rejects=1, stagnation_window=99)
    require(rows_rej[-1]["stop_check"] == "max_consecutive_rejects", rows_rej[-1]["stop_check"])
    print("[7] max_consecutive_rejects OK")

    # 8. Duplicate detection across runs
    rl.LEDGER_PATH = Path(td) / "dup.jsonl"
    rl.run_loop(max_attempts=6, max_consecutive_rejects=99, stagnation_window=99)
    rows2 = rl.run_loop(max_attempts=6, max_consecutive_rejects=99, stagnation_window=99)
    require(any(r["duplicate_candidate"] for r in rows2), "no duplicate detected on 2nd run")
    print("[8] duplicate detection OK")

    # 9. gate_decision backward compatibility
    bad = {"param": 0.95, "rule": "aggressive", "template": "T1"}
    ev = evaluate_candidate(bad)
    require(ev["invariant_violation_count"] > 0, "bad candidate not invariant-failing")
    dec, reason = gate_decision(ev, incumbent_score=0.0, min_improvement=0.0, duplicate_candidate=False)
    require(dec == "REJECT", f"expected REJECT got {dec}")
    require(reason == "rejected_invariant_violation", f"wrong reason: {reason}")
    print("[9] gate_decision backward compat OK")

    # 10. GovernanceEnforcer emits PolicyViolation for invariant
    enforcer = GovernanceEnforcer()
    pd = enforcer.enforce("hash123", ev, incumbent_score=0.0, min_improvement=0.0, duplicate_candidate=False)
    require(pd.decision == "REJECT", "enforcer did not reject")
    require(any(v.code == "INVARIANT_VIOLATION" for v in pd.violations), "INVARIANT_VIOLATION missing")
    print("[10] GovernanceEnforcer PolicyViolation OK")

    # 11. Lockdown after N consecutive fatal violations
    enforcer2 = GovernanceEnforcer()
    err_ev = {"eval_status": "error", "final_score": -1e9, "invariant_violation_count": 0, "invariant_pass": False}
    for _ in range(GovernanceEnforcer.LOCKDOWN_THRESHOLD):
        enforcer2.enforce("h", err_ev, 0.0, 0.0, False)
    require(enforcer2.is_locked_down, "lockdown not triggered")
    ok_ev = {"eval_status": "ok", "final_score": 999.0, "invariant_violation_count": 0, "invariant_pass": True}
    post_pd = enforcer2.enforce("h2", ok_ev, 0.0, 0.0, False)
    require(post_pd.decision == "REJECT", "post-lockdown should still REJECT")
    require(any(v.code == "SYSTEM_LOCKDOWN" for v in post_pd.violations), "SYSTEM_LOCKDOWN missing")
    print(f"[11] lockdown OK (threshold={GovernanceEnforcer.LOCKDOWN_THRESHOLD})")

    # 12. policy_violations is a list in all rows
    for row in rows:
        require("policy_violations" in row, "policy_violations missing")
        require(isinstance(row["policy_violations"], list), "not a list")
    print("[12] policy_violations array OK")

    # --- Phase P assertions ---

    # 13. exploration_status present in all rows
    for row in rows:
        require("exploration_status" in row, "exploration_status missing")
        es = row["exploration_status"]
        required_es = {
            "reject_ratio", "diversity_score", "stagnation_count",
            "override_active", "override_reason",
            "override_attempts_used", "override_budget",
            "escape_adopt_count", "escape_novel_count",
        }
        require(set(es.keys()) == required_es, f"exploration_status keys: {set(es.keys())}")
    print("[13] exploration_status field OK")

    # 14. ExplorationGovernor: stagnation override activates
    gov = ExplorationGovernor(policy=ExplorationPolicy(stagnation_tolerance=3, window_size=5))
    for _ in range(3):
        gov.record("REJECT", "sha256:" + "a" * 64, improving=False)
    require(gov.is_override_active, "stagnation override not triggered")
    require(gov.current_status().override_reason == "STAGNATION_OVERRIDE", "wrong reason")
    print("[14] stagnation override OK")

    # 15. adjusted_min_improvement returns 0.0 when override active
    require(gov.adjusted_min_improvement(0.01) == 0.0, "min_improvement not relaxed")
    print("[15] adjusted_min_improvement override OK")

    # 16. Override deactivates after improving attempt
    gov.record("ADOPT", "sha256:" + "b" * 64, improving=True)
    require(not gov.is_override_active, "override should deactivate after improving")
    require(gov.adjusted_min_improvement(0.01) == 0.01, "min not restored")
    print("[16] stagnation override deactivation OK")

    # --- Phase Q assertions ---

    # 20. Override budget: deactivates after override_budget attempts, resets stagnation
    gov_q = ExplorationGovernor(policy=ExplorationPolicy(
        stagnation_tolerance=2, override_budget=3, window_size=10, max_reject_ratio=1.1,
    ))
    # trigger stagnation override
    gov_q.record("REJECT", "sha256:" + "e" * 64, improving=False)
    gov_q.record("REJECT", "sha256:" + "e" * 64, improving=False)
    require(gov_q.is_override_active, "override should be active")
    # consume budget through boundary (active count goes 1 -> 2 -> 3[exhaust])
    for _ in range(2):
        gov_q.record("REJECT", "sha256:" + "f" * 64, improving=False)
    require(not gov_q.is_override_active, "override should be deactivated by budget")
    require(gov_q.current_status().stagnation_count == 0, "stagnation_count not reset")
    print("[20] override_budget deactivation OK")

    # 21. override_attempts_used tracks episode length
    status_q = gov_q.current_status()
    require(status_q.override_attempts_used == 3, f"expected 3 got {status_q.override_attempts_used}")
    require(status_q.override_budget == 3, "override_budget mismatch")
    print("[21] override_attempts_used OK")

    # 22. OVERRIDE_BUDGET_EXCEEDED warning fires (post-record, budget turn)
    gov_q2 = ExplorationGovernor(policy=ExplorationPolicy(
        stagnation_tolerance=1, override_budget=2, window_size=10,
    ))
    gov_q2.record("REJECT", "sha256:" + "g" * 64, improving=False)  # triggers override
    gov_q2.record("REJECT", "sha256:" + "g" * 64, improving=False)  # attempt 1
    budget_viols = gov_q2.health_violations()
    require(any(v.code == "OVERRIDE_BUDGET_EXCEEDED" for v in budget_viols), "OVERRIDE_BUDGET_EXCEEDED missing")
    require(all(v.severity == "WARNING" for v in budget_viols), "severity must be WARNING")
    print("[22] OVERRIDE_BUDGET_EXCEEDED WARNING OK")

    # 23. escape_adopt_count / escape_novel_count tracked per episode
    gov_q3 = ExplorationGovernor(policy=ExplorationPolicy(
        stagnation_tolerance=1, override_budget=5, window_size=10, max_reject_ratio=1.1,
    ))
    gov_q3.record("REJECT", "sha256:" + "h" * 64, improving=False)  # triggers override
    gov_q3.record("ADOPT",  "sha256:" + "i" * 64, improving=True)   # adopt during override
    s3 = gov_q3.current_status()
    require(s3.escape_adopt_count >= 1, f"escape_adopt_count={s3.escape_adopt_count}")
    require(s3.escape_novel_count >= 1, f"escape_novel_count={s3.escape_novel_count}")
    print("[23] escape proof metrics OK")

    # 24. Phase Q fields present in all ledger rows (default run)
    for row in rows:
        es = row["exploration_status"]
        require("override_attempts_used" in es, "override_attempts_used missing from ledger")
        require("escape_adopt_count" in es, "escape_adopt_count missing from ledger")
    print("[24] Phase Q fields in all ledger rows OK")

    # 17. EXPLORATION_EXHAUSTED warning emitted when reject_ratio exceeds threshold
    gov2 = ExplorationGovernor(policy=ExplorationPolicy(max_reject_ratio=0.5, window_size=4))
    for _ in range(4):
        gov2.record("REJECT", f"sha256:{'c'*64}", improving=False)
    viols = gov2.health_violations()
    require(any(v.code == "EXPLORATION_EXHAUSTED" for v in viols), "EXPLORATION_EXHAUSTED missing")
    require(all(v.severity == "WARNING" for v in viols), "health violations must be WARNING")
    print("[17] EXPLORATION_EXHAUSTED WARNING OK")

    # 18. DIVERSITY_COLLAPSE warning emitted when candidates are identical
    gov3 = ExplorationGovernor(policy=ExplorationPolicy(min_diversity_score=0.5, window_size=4))
    for _ in range(4):
        gov3.record("REJECT", "sha256:" + "d" * 64, improving=False)
    viols3 = gov3.health_violations()
    require(any(v.code == "DIVERSITY_COLLAPSE" for v in viols3), "DIVERSITY_COLLAPSE missing")
    print("[18] DIVERSITY_COLLAPSE WARNING OK")

    # 19. Health violations are WARNING — never FATAL/CRITICAL
    # Already verified in [17]; double-check that enforcer's hard stops remain unaffected
    bad = {"param": 0.95, "rule": "aggressive", "template": "T1"}
    ev_bad = evaluate_candidate(bad)
    hard_enforcer = GovernanceEnforcer()
    hard_pd = hard_enforcer.enforce("h", ev_bad, 0.0, 0.0, False)
    require(hard_pd.decision == "REJECT", "hard gate must still reject")
    require(any(v.severity == "FATAL" for v in hard_pd.violations), "FATAL must still appear from enforcer")
    print("[19] hard gate unaffected by exploration layer OK")

    decisions = {
        "ADOPT": sum(1 for r in rows if r["decision"] == "ADOPT"),
        "REJECT": sum(1 for r in rows if r["decision"] == "REJECT"),
    }

    # --- Phase R: override_observer assertions ---

    def _es(override_active=False, override_reason=None, override_attempts_used=0,
            override_budget=5, escape_adopt_count=0, escape_novel_count=0):
        """Helper: build a minimal exploration_status dict for observer tests."""
        return {
            "override_active": override_active,
            "override_reason": override_reason,
            "override_attempts_used": override_attempts_used,
            "override_budget": override_budget,
            "escape_adopt_count": escape_adopt_count,
            "escape_novel_count": escape_novel_count,
        }

    # [25] Episode detection: single STAGNATION_OVERRIDE episode, improving_escape outcome
    rows_25 = [
        {"seq": 1, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es()},
        {"seq": 2, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=True, override_reason="STAGNATION_OVERRIDE",
                                   override_attempts_used=1, escape_novel_count=1)},
        {"seq": 3, "decision": "ADOPT", "policy_violations": [],
         "exploration_status": _es(override_active=False, override_attempts_used=1,
                                   escape_adopt_count=1, escape_novel_count=1)},
    ]
    eps25 = extract_episodes(rows_25)
    require(len(eps25) == 1, f"[25] expected 1 episode, got {len(eps25)}")
    e25 = eps25[0]
    require(e25.episode_id == 1, f"[25] episode_id={e25.episode_id}")
    require(e25.start_seq == 2, f"[25] start_seq={e25.start_seq}")
    require(e25.end_seq == 3, f"[25] end_seq={e25.end_seq}")
    require(e25.trigger_reason == "STAGNATION_OVERRIDE", f"[25] trigger={e25.trigger_reason}")
    require(e25.outcome == "improving_escape", f"[25] outcome={e25.outcome}")
    require(e25.escape_adopt_count == 1, f"[25] escape_adopt={e25.escape_adopt_count}")
    print("[25] episode detection + improving_escape outcome OK")

    # [26] Outcome: budget_exhausted when OVERRIDE_BUDGET_EXCEEDED in policy_violations
    rows_26 = [
        {"seq": 10, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=True, override_reason="STAGNATION_OVERRIDE",
                                   override_attempts_used=2, escape_novel_count=2)},
        {"seq": 11, "decision": "REJECT",
         "policy_violations": [{"code": "OVERRIDE_BUDGET_EXCEEDED", "severity": "WARNING",
                                 "message": "budget exhausted"}],
         "exploration_status": _es(override_active=False, override_attempts_used=3,
                                   override_budget=3, escape_novel_count=2)},
    ]
    eps26 = extract_episodes(rows_26)
    require(len(eps26) == 1, f"[26] expected 1 episode, got {len(eps26)}")
    e26 = eps26[0]
    require(e26.outcome == "budget_exhausted", f"[26] outcome={e26.outcome}")
    require(e26.budget_used == 3, f"[26] budget_used={e26.budget_used}")
    require(e26.escape_novel_count == 2, f"[26] escape_novel={e26.escape_novel_count}")
    print("[26] budget_exhausted outcome OK")

    # [27] Outcome: passive_deactivate when override ends without ADOPT and no budget violation
    rows_27 = [
        {"seq": 20, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=True, override_reason="EXPLORATION_EXHAUSTED",
                                   override_attempts_used=2)},
        {"seq": 21, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=False, override_attempts_used=2)},
    ]
    eps27 = extract_episodes(rows_27)
    require(len(eps27) == 1, f"[27] expected 1 episode, got {len(eps27)}")
    e27 = eps27[0]
    require(e27.outcome == "passive_deactivate", f"[27] outcome={e27.outcome}")
    require(e27.trigger_reason == "EXPLORATION_EXHAUSTED", f"[27] trigger={e27.trigger_reason}")
    print("[27] passive_deactivate outcome OK")

    # [28] Run-truncated: override still active at end of rows
    rows_28 = [
        {"seq": 30, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es()},
        {"seq": 31, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=True, override_reason="STAGNATION_OVERRIDE",
                                   override_attempts_used=1, escape_novel_count=1)},
        {"seq": 32, "decision": "REJECT", "policy_violations": [],
         "exploration_status": _es(override_active=True, override_reason="STAGNATION_OVERRIDE",
                                   override_attempts_used=2, escape_novel_count=2)},
    ]
    eps28 = extract_episodes(rows_28)
    require(len(eps28) == 1, f"[28] expected 1 episode, got {len(eps28)}")
    e28 = eps28[0]
    require(e28.outcome == "run_truncated", f"[28] outcome={e28.outcome}")
    require(e28.start_seq == 31, f"[28] start_seq={e28.start_seq}")
    require(e28.end_seq == 32, f"[28] end_seq={e28.end_seq}")
    require(e28.escape_novel_count == 2, f"[28] escape_novel={e28.escape_novel_count}")
    print("[28] run_truncated outcome OK")

    # --- Phase S: override_analytics assertions ---

    episodes_s = [
        OverrideEpisode(
            episode_id=1,
            start_seq=2,
            end_seq=4,
            trigger_reason="STAGNATION_OVERRIDE",
            budget_used=3,
            escape_adopt_count=1,
            escape_novel_count=2,
            outcome="improving_escape",
        ),
        OverrideEpisode(
            episode_id=2,
            start_seq=8,
            end_seq=10,
            trigger_reason="STAGNATION_OVERRIDE",
            budget_used=3,
            escape_adopt_count=0,
            escape_novel_count=2,
            outcome="budget_exhausted",
        ),
        OverrideEpisode(
            episode_id=3,
            start_seq=12,
            end_seq=13,
            trigger_reason="EXPLORATION_EXHAUSTED",
            budget_used=2,
            escape_adopt_count=0,
            escape_novel_count=1,
            outcome="passive_deactivate",
        ),
    ]

    # [29] KPI集計: episode群から主要KPIが正しく計算される
    report_s = analyze_episodes(episodes_s)
    require(report_s.episode_count == 3, f"[29] episode_count={report_s.episode_count}")
    require(report_s.attempt_span == 12, f"[29] attempt_span={report_s.attempt_span}")
    require(report_s.avg_episode_length == 2.6667, f"[29] avg_episode_length={report_s.avg_episode_length}")
    require(report_s.override_frequency == 0.25, f"[29] override_frequency={report_s.override_frequency}")
    print("[29] KPI aggregation OK")

    # [30] outcome比率: improving_escape / budget_exhaust が期待通り
    require(report_s.improving_escape_rate == 0.3333, f"[30] improving_escape_rate={report_s.improving_escape_rate}")
    require(report_s.budget_exhaust_rate == 0.3333, f"[30] budget_exhaust_rate={report_s.budget_exhaust_rate}")
    require(report_s.passive_deactivate_rate == 0.3333, f"[30] passive_deactivate_rate={report_s.passive_deactivate_rate}")
    require(report_s.run_truncated_rate == 0.0, f"[30] run_truncated_rate={report_s.run_truncated_rate}")
    print("[30] outcome rates OK")

    # [31] deterministic提案: 同じ入力では同じ recommendation が返る
    report_s2 = analyze_episodes(episodes_s)
    require(report_s.to_dict() == report_s2.to_dict(), "[31] report not deterministic")
    print("[31] deterministic recommendation/report OK")

    # [32] warning判定: 閾値を厳しくすると HEALTHY -> AT_RISK / EXHAUSTED へ遷移
    at_risk_thresholds = AnalyticsThresholds(
        min_improving_escape_rate=0.2,
        max_budget_exhaust_rate=0.3,
        max_override_frequency=0.2,
    )
    report_at_risk = analyze_episodes(episodes_s, thresholds=at_risk_thresholds)
    require(report_at_risk.health_status == "AT_RISK", f"[32] health_status={report_at_risk.health_status}")
    require("increase_cooldown" in report_at_risk.recommended_adjustments,
            "[32] missing increase_cooldown")
    require("lower_base_min_improvement" in report_at_risk.recommended_adjustments,
            "[32] missing lower_base_min_improvement")

    exhausted_thresholds = AnalyticsThresholds(
        min_improving_escape_rate=0.6,
        max_budget_exhaust_rate=0.3,
        max_override_frequency=0.2,
    )
    episodes_exhausted = [
        OverrideEpisode(1, 1, 3, "STAGNATION_OVERRIDE", 3, 0, 2, "budget_exhausted"),
        OverrideEpisode(2, 5, 7, "STAGNATION_OVERRIDE", 3, 0, 2, "budget_exhausted"),
    ]
    report_exhausted = analyze_episodes(episodes_exhausted, thresholds=exhausted_thresholds)
    require(report_exhausted.health_status == "EXHAUSTED",
            f"[32] exhausted health_status={report_exhausted.health_status}")
    print("[32] health judgment threshold transitions OK")

print()
print("TEST_RESULT: PASS (Phase O + P + Q + R + S)")
print(f"default_attempts={len(rows)}, last_stop={rows[-1]['stop_check']}")
print(f"decisions={decisions}")
print(f"hash_chain_verified=True, lockdown_threshold={GovernanceEnforcer.LOCKDOWN_THRESHOLD}")
last_es = rows[-1]["exploration_status"]
print(f"final_exploration_status={last_es}")
