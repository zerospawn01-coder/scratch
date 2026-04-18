import copy
import random
from typing import Dict


def mutate_candidate(incumbent: Dict, candidate_id: str, mutation_type: str = "param_shift") -> Dict:
    candidate = copy.deepcopy(incumbent)
    candidate["candidate_id"] = candidate_id
    candidate["parent_candidate_id"] = incumbent["candidate_id"]
    candidate["mutation_type"] = mutation_type

    if mutation_type == "param_shift":
        delta = random.uniform(-0.08, 0.08)
        candidate["param"] = max(0.0, min(1.0, candidate["param"] + delta))
    elif mutation_type == "rule_replace":
        candidate["rule"] = "conservative" if candidate.get("rule") == "aggressive" else "aggressive"
    elif mutation_type == "template_swap":
        candidate["template"] = "T2" if candidate.get("template") == "T1" else "T1"

    return candidate
