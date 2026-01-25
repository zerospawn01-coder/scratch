from typing import Dict, Any, List
from conversation_braid import ConversationBraid
from frustration_monitor import FrustrationMonitor

class TopologicalAuditor:
    """
    T-IAT Topological Auditor "The Sentinel"
    Orchestrates the Weaver (BraidEngine) and The Whisperer (FrustrationMonitor)
    to sanitize LLM inputs and guard against informational labyrinths.
    """

    def __init__(self, n_strands: int = 10):
        self.loom = ConversationBraid(n_strands=n_strands)
        self.monitor = FrustrationMonitor(self.loom)
        self.audit_log = []

    def audit_step(self, semantic_ops: List[str]) -> Dict[str, Any]:
        """
        Processes a set of semantic operations (e.g., from RAG chunks)
        and returns the consolidated frustration state.
        """
        last_metrics = {}
        for op in semantic_ops:
            self.loom.push_semantic_op(op)
            last_metrics = self.monitor.analyze_turn(op)
        
        self.audit_log.append(last_metrics)
        return last_metrics

    def generate_sanity_report(self) -> str:
        """
        Generates a human-readable summary of the topological state.
        """
        if not self.audit_log:
            return "No audit data."
            
        latest = self.audit_log[-1]
        alert = latest['alert']
        f_score = latest['f_score']
        
        report = f"--- TOPOLOGICAL SANITY REPORT ---\n"
        report += f"ALERT LEVEL: {alert}\n"
        report += f"FRUSTRATION SCORE: {f_score:.2f}\n"
        
        if alert == "CRITICAL":
            report += "WARNING: Reality Divergence Detected. Internal consistency is fractured.\n"
        elif alert == "WARN":
            report += "ADVISORY: Sustained topological strain. RAG information may be contradictory.\n"
        else:
            report += "STATUS: Structural integrity maintained.\n"
            
        return report

    def mock_llm_call(self, query: str, rag_context: str) -> str:
        """
        Simplified pipeline: RAG -> Audit -> Decision -> Mock Response.
        """
        print(f"User Query: {query}")
        print(f"RAG Context: {rag_context[:50]}...")
        
        # MAPPING (Simplified heuristic for the MTP Day 4)
        # In a real system, we'd use embedding distance to map to ops.
        ops = ["ASSERT"] # Assume RAG is an assertion
        if "not" in rag_context or "false" in rag_context:
            ops = ["NEGATE"]
            
        metrics = self.audit_step(ops)
        report = self.generate_sanity_report()
        
        print(report)
        
        if metrics['alert'] == "CRITICAL":
            return "[T-IAT BLOCK] High Frustration: I cannot provide a reliable answer due to record inconsistency."
            
        return f"Mock LLM Response based on verified topological state: [Correct/Consistent Output]"

if __name__ == "__main__":
    auditor = TopologicalAuditor()
    
    # Scenario: The Eternal City Paradox
    print("Scenario: The Paradox of Aethelgard")
    print(auditor.mock_llm_call("How was Aethelgard founded?", "Aethelgard was founded on pure water and open gates."))
    
    print("\n--- 5000 tokens later ---")
    # This negation triggers frustration because it violates the initial assertion.
    print(auditor.mock_llm_call("Check excavations.", "New evidence says Aethelgard was a stone fortress with no gates."))
