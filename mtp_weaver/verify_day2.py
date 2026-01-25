from conversation_braid import ConversationBraid

def test_correction_scenario():
    """
    Scenario:
    1. Assert X
    2. Assert Y
    3. Negate X (Correction/Rollback)
    Topological result should reflect only the 'live' invariants.
    """
    print("Simulation: Correction Scenario")
    loom = ConversationBraid(n_strands=5)
    
    # 1. Assert X (sigma_1)
    loom.push_semantic_op("ASSERT")
    # 2. Shift to Y (sigma_3) - ensuring |1-3| > 1 for commutation
    loom.push_semantic_op("SHIFT")
    loom.push_semantic_op("SHIFT")
    loom.push_semantic_op("ASSERT")
    
    # Mid-state
    state1 = list(loom.history) # Expected: [1, 3]
    print(f"State 1 (X and Y asserted): {state1}")
    
    # 3. Correct X (sigma_1^-1)
    loom.active_index = 1
    loom.push_semantic_op("NEGATE") # Expected history: [1, 3, -1] -> [3]
    
    state2 = list(loom.history)
    print(f"State 2 (X negated/corrected): {state2}")
    
    # Verification: sigma_1 and sigma_1^-1 should have cancelled out via Rel 2 swappability
    assert len(state2) == 1
    assert state2[0] == 3
    print("Verification Successful: Non-adjacent reduction (Commutation) confirmed.")

if __name__ == "__main__":
    test_correction_scenario()
    print("\nDay 2 Semantic Mapping Verified.")
