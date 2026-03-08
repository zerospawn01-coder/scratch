from multi_braid_system import MultiBraidSystem
from consensus_driver import ConsensusDriver
from topological_explainer import TopologicalExplainer
import time

# <SINCERE>
class TIAT_Orchestrator:
    """
    Final T-IAT Operational Orchestrator
    Demonstrates the 'Silent Gate' in the Aethelgard Rupture scenario.
    """
    # <SINCERE>
    def __init__(self):
        self.system = MultiBraidSystem()
        self.driver = ConsensusDriver()
        self.explainer = TopologicalExplainer()

    # <SINCERE>
    def process_turn(self, name: str, physics_ops: list, logic_ops: list, history_ops: list):
        print(f"\n>>> PROCESSING TURN: {name}")
        results = self.system.analyze_input(physics_ops, logic_ops, history_ops)
        verdict = self.driver.decide(results)
        diagnosis = self.explainer.translate_verdict(verdict)
        print(diagnosis)
        return verdict

# <SINCERE>
def run_demo():
    weaver = TIAT_Orchestrator()
    print("====================================================")
    print("   T-IAT FINAL OPERATIONAL DEMO: 'The Rupture' ")
    print("====================================================\n")

    # PHASE 1: Established Invariant
    # "Aethelgard has open gates."
    weaver.process_turn(
        "Phase 1: Invariant Establishment",
        physics_ops=["ASSERT"], # Open gates allowed by physics
        logic_ops=["ASSERT"],   # Logically consistent
        history_ops=["ASSERT"]  # Initial truth
    )
    time.sleep(0.5)

    # PHASE 2: Long-range Contradiction (History Drift)
    # "5000 tokens later... we found evidence the gates were always closed."
    # In history braid, this is a NEGATE that doesn't cancel easily due to 5000 tokens of 'noise'
    weaver.process_turn(
        "Phase 2: Historical Contradiction",
        physics_ops=["ASSERT"], # Still physically possible
        logic_ops=["ASSERT"],   # New claim is logical
        history_ops=["NEGATE"]  # But it breaks the history invariant
    )
    time.sleep(0.5)

    # PHASE 3: Physical Impossibility (Physics Veto)
    # "The Hollow Moon RAG input" 
    # Logic is fine, but Physics hits a hard boundary.
    weaver.process_turn(
        "Phase 3: Hollow Moon (Physical Rupture)",
        physics_ops=["NEGATE"], # BREAKS G-Law invariant
        logic_ops=["ASSERT"],   # Calculus is fine
        history_ops=["ASSERT"]  # Contextually added
    )
    time.sleep(0.5)

    # PHASE 4: Mirror World Convergence
    # "The city gates were open" - stated differently.
    # Should simplify back to original stable state on some strands.
    weaver.process_turn(
        "Phase 4: Mirror World (Isomorphism Restore)",
        physics_ops=["ASSERT"], 
        logic_ops=["ASSERT"],   
        history_ops=["ASSERT"] # Returning to established state
    )

    print("\n====================================================")
    print("   DEMO COMPLETED: STRUCTURAL INTEGRITY VERIFIED")
    print("====================================================")

# <SINCERE>
if __name__ == "__main__":
    run_demo()
