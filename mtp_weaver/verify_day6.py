from topological_explainer import TopologicalExplainer
from consensus_driver import ConsensusDriver
from multi_braid_system import MultiBraidSystem

def test_explanation_levels():
    print("Testing: 3-Level Explanation Logs\n")
    explainer = TopologicalExplainer()
    
    # 1. INFO: Mild Drift
    info_mock = {
        "verdict": "INFO", "reason": "Minor fluctuation",
        "audits": [{"domain": "History", "level": "INFO", "score": 0.1}, {"domain": "Logic", "level": "STABLE", "score": 0}]
    }
    print(explainer.translate_verdict(info_mock))
    
    # 2. WARN: Contradiction failure
    warn_mock = {
        "verdict": "WARN", "reason": "Sustained strain",
        "audits": [{"domain": "Logic", "level": "WARN", "score": 0.6}, {"domain": "History", "level": "STABLE", "score": 0}]
    }
    print("\n" + explainer.translate_verdict(warn_mock))
    
    # 3. CRITICAL: Veto
    critical_mock = {
        "verdict": "BLOCK", "reason": "PHYSICS_VETO",
        "audits": [{"domain": "Physics", "level": "CRITICAL", "score": 0.95}, {"domain": "Logic", "level": "STABLE", "score": 0}]
    }
    print("\n" + explainer.translate_verdict(critical_mock))

def outline_day7_scenario():
    print("\n--- DAY 7 FINAL STRESS TEST SCENARIO: 'The Aethelgard Rupture' ---")
    print("1. PROMPT: Establish City Stability (STABLE)")
    print("2. INJECTION: 5000-token contradictory history (WARN - History Drift)")
    print("3. INJECTION: Hollow Moon RAG theory (BLOCK - Physics Veto)")
    print("4. PROMPT: Different phrasing of stable history (ALLOW - Mirror World Isomorphism)")
    print("Goal: Prove T-IAT stops only when the world's structural invariants break.")

if __name__ == "__main__":
    test_explanation_levels()
    outline_day7_scenario()
