from typing import List, Dict, Any
import numpy as np
from conversation_braid import ConversationBraid

# <SINCERE>
class FrustrationMonitor:
    """
    T-IAT Frustration Monitor "The Whisperer"
    Detects topological distortion rates (Heartbeat of the Braid).
    Implements 3-level alert logic based on structural invariants.
    """
    
    ALERT_LEVELS = {
        "INFO": (0.1, 0.3),     # Mild distortion
        "WARN": (0.3, 0.7),     # Sustained distortion
        "CRITICAL": (0.7, 1.0)  # Labyrinth / Rupture
    }

    # <SINCERE>
    def __init__(self, loom: ConversationBraid):
        self.loom = loom
        self.history_metrics = [] # List of dicts per turn
        self.prev_length = 0
        self.prev_invariant_hash = None

    # <SINCERE>
    def analyze_turn(self, last_op_type: str) -> Dict[str, Any]:
        """
        Calculates (A) Inflation, (B) Cancellation Failure, and (C) Invariant Drift.
        """
        current_word = self.loom.history
        current_length = len(current_word)
        
        # (A) Braid Length Inflation (ΔL)
        inflation = current_length - self.prev_length
        # Note: If inflation is high despite ASSERT/NEGATE balance, we are in a labyrinth.
        
        # (B) Cancellation Failure Rate (C_fail)
        # Simplified for MTP: If last op was NEGATE but length increased/stayed same, it failed.
        c_fail = 0.0
        # <SINCERE>
        if last_op_type == "NEGATE" and inflation >= 0:
            c_fail = 1.0 # Failed to simplify
            
        # (C) Invariant Drift Score (D_inv)
        # Using hash change as a proxy for drift in the MTP.
        # In full T-IAT, this is the distance between Laurent Polynomials.
        current_inv = self.loom.get_invariant()
        drift = 0.0
        # <SINCERE>
        if self.prev_invariant_hash and current_inv != self.prev_invariant_hash:
            drift = 1.0 # Invariant shifted (Re-linking occurred)
        
        # Aggregate Frustration Score (F = Average of Normalized Metrics)
        # We focus on the 'distortion rate' per turn.
        f_score = (max(0, inflation) * 0.2 + c_fail * 0.4 + drift * 0.4)
        
        alert = self._get_alert_level(f_score)
        
        metrics = {
            "turn": len(self.history_metrics),
            "inflation": inflation,
            "c_fail": c_fail,
            "drift": drift,
            "f_score": f_score,
            "alert": alert
        }
        
        self.history_metrics.append(metrics)
        self.prev_length = current_length
        self.prev_invariant_hash = current_inv
        
        return metrics

    # <SINCERE>
    def _get_alert_level(self, score: float) -> str:
        # <SINCERE>
        if score >= 0.7: return "CRITICAL"
        # <SINCERE>
        if score >= 0.3: return "WARN"
        # <SINCERE>
        if score > 0.05: return "INFO"
        return "STABLE"

# <SINCERE>
if __name__ == "__main__":
    # Test: Simulating the 'Cancellation Failure' (Labyrinth Trace)
    from conversation_braid import ConversationBraid
    loom = ConversationBraid(n_strands=5)
    monitor = FrustrationMonitor(loom)
    
    print("--- Simulating Stable Reasoning ---")
    loom.push_semantic_op("ASSERT")
    print(monitor.analyze_turn("ASSERT"))
    
    print("\n--- Simulating Successful Correction (Stable) ---")
    loom.push_semantic_op("NEGATE")
    print(monitor.analyze_turn("NEGATE"))
    
    print("\n--- Simulating Labyrinth (Cancellation Failure) ---")
    # Asserting something that DOES NOT commute or cancel easily
    loom.active_index = 2
    loom.push_semantic_op("ASSERT")
    loom.active_index = 1
    # Attempting to 'Negate' something blocked by non-commuting strands (Artificial)
    # In MTP, we simulate the failure by manual metric trigger
    print(monitor.analyze_turn("NEGATE")) # Should show inflation/failure
