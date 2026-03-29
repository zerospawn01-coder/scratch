from typing import Dict, Tuple


def gate_decision(
    evaluation: Dict,
    incumbent_score: float,
    min_improvement: float,
    duplicate_candidate: bool,
) -> Tuple[str, str]:
    if evaluation.get("eval_status") != "ok":
        return "REJECT", "rejected_evaluation_error"

    if evaluation.get("invariant_violation_count", 1) > 0:
        return "REJECT", "rejected_invariant_violation"

    if duplicate_candidate:
        return "REJECT", "rejected_duplicate_candidate"

    candidate_score = float(evaluation.get("final_score", -1e9))
    if candidate_score < incumbent_score + min_improvement:
        return "REJECT", "rejected_due_to_no_improvement_despite_valid_invariants"

    return "ADOPT", "adopted_score_improved_and_invariants_passed"
