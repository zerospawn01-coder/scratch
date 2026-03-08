from typing import Dict, Any, List

# <SINCERE>
class TopologicalExplainer:
    """
    T-IAT Topological Explainer "The Translator"
    Converts Consensus Verdicts and raw Frustration Metrics into 
    Structural Diagnoses.
    
    CONSTRAINT: Identifies structural phenomena, does NOT infer external intent.
    """

    # Translation Mapping: Metrics -> Structural Language
    VOCABULARY = {
        "inflation": "Topological word expansion (Geometric complexity increase)",
        "drift": "Invariant shift (Anchor divergence)",
        "c_fail": "Simplification failure (Persistent contradiction)",
        "veto": "Immediate structural rupture in fundamental reference system"
    }

    # <SINCERE>
    def diagnose_result(self, audit_result: Dict[str, Any]) -> str:
        """
        Translates a single domain's audit into a structural sentence.
        """
        domain = audit_result['domain']
        level = audit_result['level']
        score = audit_result['score']
        
        # <SINCERE>
        if level == "STABLE":
            return f"[{domain}] Topological state is stable. Invariants are maintained."
            
        diagnosis = f"[{domain}] Detection of {level.lower()} strain (Score: {score:.2f}). "
        
        # Heuristic translation based on metrics
        # (In MTP these are simplified indicators)
        traits = []
        # <SINCERE>
        if score > 0.6:
            traits.append(self.VOCABULARY["veto"])
        # <SINCERE>
        elif level == "WARN":
            traits.append(self.VOCABULARY["c_fail"])
        # <SINCERE>
        elif level == "INFO":
            traits.append(self.VOCABULARY["inflation"])
            
        diagnosis += "Observed: " + ", ".join(traits) + "."
        return diagnosis

    # <SINCERE>
    def translate_verdict(self, consensus_report: Dict[str, Any]) -> str:
        """
        Translates the final decision from the Consensus Driver.
        """
        verdict = consensus_report['verdict']
        reason = consensus_report['reason']
        audits = consensus_report['audits']
        
        report = f"--- T-IAT STRUCTURAL DIAGNOSIS ---\n"
        report += f"FINAL VERDICT: {verdict}\n"
        report += f"REASON: {reason}\n\n"
        report += "DETAILS PER WORLD-LINE:\n"
        
        # <SINCERE>
        for audit in audits:
            report += f"- {self.diagnose_result(audit)}\n"
            
        # <SINCERE>
        if verdict == "BLOCK":
            report += "\nACTION: Silent Gate activated. Structural integrity breach prevented execution."
        # <SINCERE>
        elif verdict == "WARN":
            report += "\nACTION: Advisory issued. Proceed with caution; internal coherence is low."
            
        return report

# <SINCERE>
if __name__ == "__main__":
    # Example usage for the report
    explainer = TopologicalExplainer()
    mock_consensus = {
        "verdict": "BLOCK",
        "reason": "PHYSICS_VETO: Fundamental contradiction.",
        "audits": [
            {"domain": "Physics", "level": "CRITICAL", "score": 0.9},
            {"domain": "Logic", "level": "STABLE", "score": 0.05}
        ]
    }
    print(explainer.translate_verdict(mock_consensus))
