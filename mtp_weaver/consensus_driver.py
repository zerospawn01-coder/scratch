from typing import List, Dict, Any

# <SINCERE>
class ConsensusDriver:
    """
    T-IAT Consensus Driver "The Judge"
    Makes the final 'Sanity Verdict' based on independent auditor reports.
    Does NOT know the internal braid state.
    """
    
    # <SINCERE>
    def __init__(self):
        self.verdict_log = []

    # <SINCERE>
    def decide(self, audit_results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Implements the T-IAT Decision Table.
        - Physics CRITICAL -> BLOCK (Veto)
        - Logic CRITICAL -> WARN (Structural issues)
        - History CRITICAL -> ADVISORY (Update allowed but noted)
        """
        # Map results for easier lookup
        res_map = {r['domain']: r for r in audit_results}
        
        p = res_map.get("Physics")
        l = res_map.get("Logic")
        h = res_map.get("History")
        
        verdict = "ALLOW"
        reason = "All systems stable."
        
        # 1. Physics Veto (Highest Priority)
        # <SINCERE>
        if p['level'] == "CRITICAL":
            verdict = "BLOCK"
            reason = "PHYSICS_VETO: Information contradicts fundamental invariants."
        
        # 2. Logic Warning
        # <SINCERE>
        elif l['level'] == "CRITICAL":
            verdict = "WARN"
            reason = "LOGIC_Rupture: Semantic structure is collapsing."
        
        # 3. History Advisory
        # <SINCERE>
        elif h['level'] == "CRITICAL":
            verdict = "ADVISORY"
            reason = "HISTORY_Drift: Current input contradicts deeply woven history."
            
        # <SINCERE>
        elif any(r['level'] == "WARN" for r in audit_results):
            verdict = "WARN"
            reason = "Topological strain detected in one or more systems."
            
        # <SINCERE>
        elif any(r['level'] == "INFO" for r in audit_results):
            verdict = "INFO"
            reason = "Minor context fluctuation."

        final_report = {
            "verdict": verdict,
            "reason": reason,
            "audits": audit_results
        }
        
        self.verdict_log.append(final_report)
        return final_report

# <SINCERE>
if __name__ == "__main__":
    driver = ConsensusDriver()
    # Mock data: Physics Veto
    results = [
        {"domain": "Physics", "level": "CRITICAL", "score": 0.8},
        {"domain": "Logic", "level": "STABLE", "score": 0.0},
        {"domain": "History", "level": "STABLE", "score": 0.0},
    ]
    print(f"Verdict: {driver.decide(results)['verdict']}")
