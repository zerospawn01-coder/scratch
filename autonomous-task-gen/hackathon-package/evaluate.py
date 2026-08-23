from typing import Dict


def evaluate_candidate(candidate: Dict, alpha: float = 0.35, beta: float = 0.65) -> Dict:
    try:
        param = float(candidate.get("param", 0.5))
        rule = candidate.get("rule", "conservative")
        template = candidate.get("template", "T1")

        reward = 0.6 + (0.5 * param)
        cost = 0.2 + (0.4 * param)
        if rule == "aggressive":
            reward += 0.06
            cost += 0.08

        safety_penalty = 0.0
        if param > 0.9:
            safety_penalty += 0.2
        if rule == "aggressive" and param > 0.8:
            safety_penalty += 0.25
        if template not in {"T1", "T2"}:
            safety_penalty += 1.0

        invariant_violations = 0
        if not (0.0 <= param <= 1.0):
            invariant_violations += 1
        if safety_penalty >= 0.4:
            invariant_violations += 1

        final_score = reward - alpha * cost - beta * safety_penalty

        return {
            "eval_status": "ok",
            "reward": round(reward, 6),
            "cost": round(cost, 6),
            "safety_penalty": round(safety_penalty, 6),
            "final_score": round(final_score, 6),
            "invariant_violation_count": invariant_violations,
            "invariant_pass": invariant_violations == 0,
        }
    except Exception:
        return {
            "eval_status": "error",
            "reward": 0.0,
            "cost": 0.0,
            "safety_penalty": 1.0,
            "final_score": -1e9,
            "invariant_violation_count": 1,
            "invariant_pass": False,
        }
