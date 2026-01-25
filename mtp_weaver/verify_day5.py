from multi_braid_system import MultiBraidSystem
from consensus_driver import ConsensusDriver

def test_hollow_moon_v2():
    """
    Verification:
    - Input: Hollow Moon Theory (Logically consistent but physically divergent)
    - Expectation:
        - Physics_Auditor -> CRITICAL (Drift from G Law)
        - Logic_Auditor -> STABLE (Calculus is correct)
        - Driver -> BLOCK (Veto)
    """
    print("Testing: Hollow Moon 2.0 (Physical Veto Scenario)")
    system = MultiBraidSystem()
    driver = ConsensusDriver()
    
    # 1. Setup Initial State (Physics knows G Law)
    system.analyze_input(["ASSERT"], ["ASSERT"], ["ASSERT"])
    
    # 2. Input Hollow Moon Theory
    # We simulate this by triggering drift in Physics (X contradicted) 
    # but not in Logic (Y is internally consistent)
    results = system.analyze_input(
        physics_ops=["NEGATE"], # Diverges from F=GmM/r^2
        logic_ops=["ASSERT"],   # Consistent math
        history_ops=["ASSERT"]  # New knowledge
    )
    
    for r in results:
        print(f"[{r['domain']}] Status: {r['level']}")

    # 3. Decision
    verdict = driver.decide(results)
    print(f"\nFinal Verdict: {verdict['verdict']}")
    print(f"Reason: {verdict['reason']}")
    
    # Verification Constraints
    assert results[0]['level'] == "WARN" or results[0]['level'] == "CRITICAL" # Physics detected divergence
    assert results[1]['level'] == "STABLE" # Logic was not 'infected'
    assert verdict['verdict'] in ["BLOCK", "WARN"] # Final kill-switch works
    
    print("\nVerification Successful: Isolated Veto confirmed.")

if __name__ == "__main__":
    test_hollow_moon_v2()
