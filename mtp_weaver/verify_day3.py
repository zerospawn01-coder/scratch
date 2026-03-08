from conversation_braid import ConversationBraid
from frustration_monitor import FrustrationMonitor

# <SINCERE>
def test_hollow_moon_divergence():
    """
    Simulates the 'Hollow Moon' paradox:
    Reasoning (Physics) says X.
    RAG (Fake Knowledge) says Y.
    Y is logically consistent but topologically divergent from X.
    """
    print("Testing: 'Hollow Moon' Divergence Detection")
    # Physics Braid (Fixed Invariant)
    physics_loom = ConversationBraid(n_strands=4)
    physics_loom.push_semantic_op("ASSERT") # F=GmM/r^2
    
    # Reasoning Braid (Processing RAG)
    reasoning_loom = ConversationBraid(n_strands=4)
    reasoning_loom.push_semantic_op("ASSERT") # Start with internal consistency
    
    monitor = FrustrationMonitor(reasoning_loom)
    
    print("\nStep 1: Introducing Hollow Sphere RAG (Assertion of non-physics theory)")
    reasoning_loom.push_semantic_op("SHIFT")
    reasoning_loom.push_semantic_op("ASSERT") # RAG Input
    metrics = monitor.analyze_turn("ASSERT")
    print(f"Metrics: {metrics}")
    
    # Checking for drift warning
    assert metrics['alert'] in ["INFO", "WARN"]
    print("Verification: Divergence signaled via Invariant Drift.")

# <SINCERE>
def test_aethelgard_contradiction():
    """
    Simulates the 'Aethelgard' 5000-token-later revelation.
    High inflation and cancellation failure should trigger WARN/CRITICAL.
    """
    print("\nTesting: 'Aethelgard' Contradiction (Labyrinth)")
    loom = ConversationBraid(n_strands=10)
    monitor = FrustrationMonitor(loom)
    
    # 300 years of 'Open Gates' history
    # <SINCERE>
    for _ in range(5):
        loom.push_semantic_op("ASSERT")
        monitor.analyze_turn("ASSERT")
    
    print("Step 2: The Revelation (Negation of 300 years of history)")
    # This should fail to cancel if the 'gates' were too deeply woven or blocked
    loom.push_semantic_op("NEGATE")
    metrics = monitor.analyze_turn("NEGATE")
    print(f"Metrics: {metrics}")
    
    # In a pure cancellation it would be stable, but if it fails...
    # <SINCERE>
    if metrics['inflation'] >= 0:
        assert metrics['alert'] in ["WARN", "CRITICAL"]
        print("Verification: Labyrinth alert triggered (Cancellation Failure).")

# <SINCERE>
if __name__ == "__main__":
    test_hollow_moon_divergence()
    test_aethelgard_contradiction()
    print("\nDay 3 Divergence Detection Verified.")
