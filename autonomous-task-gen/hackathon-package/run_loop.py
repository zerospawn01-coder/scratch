import hashlib
import json
import random
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List

from evaluate import evaluate_candidate  # type: ignore[import-not-found]
from evolve import mutate_candidate  # type: ignore[import-not-found]
from gate import gate_decision  # type: ignore[import-not-found]


LEDGER_PATH = Path("ledger.jsonl")


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _id(prefix: str, n: int) -> str:
    return f"{prefix}-{n:05d}"


def _candidate_hash(candidate: Dict) -> str:
    payload = {
        "param": candidate.get("param"),
        "rule": candidate.get("rule"),
        "template": candidate.get("template"),
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _load_existing_hashes(ledger_path: Path) -> set:
    hashes = set()
    if not ledger_path.exists():
        return hashes

    with ledger_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
                h = row.get("candidate_hash")
                if isinstance(h, str):
                    hashes.add(h)
            except json.JSONDecodeError:
                continue

    return hashes


def _append_ledger(ledger_path: Path, row: Dict) -> None:
    with ledger_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=True) + "\n")


def run_loop(
    max_attempts: int = 50,
    max_consecutive_rejects: int = 12,
    improvement_floor: float = 0.01,
    stagnation_window: int = 8,
    min_improvement: float = 0.005,
) -> List[Dict]:
    random.seed(42)

    incumbent = {
        "candidate_id": _id("C", 0),
        "param": 0.5,
        "rule": "conservative",
        "template": "T1",
    }
    incumbent_eval = evaluate_candidate(incumbent)
    incumbent_score = float(incumbent_eval["final_score"])

    existing_hashes = _load_existing_hashes(LEDGER_PATH)
    relative_improvement_streak = 0
    consecutive_rejects = 0
    rows = []

    for attempt_num in range(1, max_attempts + 1):
        attempt_id = _id("A", attempt_num)
        candidate_id = _id("C", attempt_num)

        mutation_type = random.choice(["param_shift", "rule_replace", "template_swap"])
        candidate = mutate_candidate(incumbent, candidate_id, mutation_type=mutation_type)
        candidate_hash = _candidate_hash(candidate)
        duplicate_candidate = candidate_hash in existing_hashes

        evaluation = evaluate_candidate(candidate)
        decision, reason = gate_decision(
            evaluation=evaluation,
            incumbent_score=incumbent_score,
            min_improvement=min_improvement,
            duplicate_candidate=duplicate_candidate,
        )

        incumbent_score_before = incumbent_score
        if decision == "ADOPT":
            incumbent = candidate
            incumbent_score = float(evaluation["final_score"])
            consecutive_rejects = 0
        else:
            consecutive_rejects += 1

        # Relative improvement is measured against the incumbent before the gate.
        denom = max(abs(incumbent_score_before), 1e-9)
        rel_improvement = (float(evaluation["final_score"]) - incumbent_score_before) / denom
        if rel_improvement <= improvement_floor:
            relative_improvement_streak += 1
        else:
            relative_improvement_streak = 0

        stop_check = "continue"
        if attempt_num >= max_attempts:
            stop_check = "max_attempts"
        elif consecutive_rejects >= max_consecutive_rejects:
            stop_check = "max_consecutive_rejects"
        elif relative_improvement_streak >= stagnation_window:
            stop_check = "stagnation"

        row = {
            "attempt_id": attempt_id,
            "timestamp": _utc_now_iso(),
            "parent_candidate_id": candidate["parent_candidate_id"],
            "candidate_id": candidate["candidate_id"],
            "candidate_hash": candidate_hash,
            "mutation_type": mutation_type,
            "reward": evaluation["reward"],
            "cost": evaluation["cost"],
            "safety_penalty": evaluation["safety_penalty"],
            "final_score": evaluation["final_score"],
            "invariant_violation_count": evaluation["invariant_violation_count"],
            "invariant_pass": evaluation["invariant_pass"],
            "eval_status": evaluation["eval_status"],
            "duplicate_candidate": duplicate_candidate,
            "decision": decision,
            "decision_reason": reason,
            "incumbent_score_before": round(incumbent_score_before, 6),
            "incumbent_score_after": round(incumbent_score, 6),
            "stop_check": stop_check,
        }

        _append_ledger(LEDGER_PATH, row)
        rows.append(row)
        existing_hashes.add(candidate_hash)

        if stop_check != "continue":
            break

    return rows


if __name__ == "__main__":
    results = run_loop()
    print(f"attempts_logged={len(results)} last_stop_check={results[-1]['stop_check'] if results else 'none'}")
