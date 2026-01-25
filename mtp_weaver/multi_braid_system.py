from typing import List, Dict, Any
from conversation_braid import ConversationBraid
from frustration_monitor import FrustrationMonitor

class IsolatedAuditor:
    """
    Independent 'World-Line' Auditor.
    Contains its own engine, braid, and monitor.
    """
    def __init__(self, domain: str, n_strands: int = 10):
        self.domain = domain
        self.loom = ConversationBraid(n_strands=n_strands)
        self.monitor = FrustrationMonitor(self.loom)

    def audit(self, ops: List[str]) -> Dict[str, Any]:
        """
        Independent audit of a semantic sequence.
        Returns normalized AuditResult-like dictionary.
        """
        last_metrics = {}
        for op in ops:
            self.loom.push_semantic_op(op)
            last_metrics = self.monitor.analyze_turn(op)
        
        return {
            "domain": self.domain,
            "level": last_metrics.get("alert", "STABLE"),
            "score": last_metrics.get("f_score", 0.0),
            "confidence": 0.95 # Mock confidence for prototype
        }

class MultiBraidSystem:
    """
    T-IAT Multi-Braid System (The Three World-Lines)
    Enforces absolute isolation between Physics, Logic, and History.
    """
    def __init__(self):
        # Three independent worlds
        self.physics = IsolatedAuditor("Physics")
        self.logic = IsolatedAuditor("Logic")
        self.history = IsolatedAuditor("History")

    def analyze_input(self, physics_ops: List[str], logic_ops: List[str], history_ops: List[str]) -> List[Dict[str, Any]]:
        """
        Parallel analysis across three independent reference systems.
        """
        # Step 1: Physics Audit (Fixed Laws)
        p_res = self.physics.audit(physics_ops)
        
        # Step 2: Logic Audit (Propositional consistency)
        l_res = self.logic.audit(logic_ops)
        
        # Step 3: History Audit (Contextual agreement)
        h_res = self.history.audit(history_ops)
        
        return [p_res, l_res, h_res]

if __name__ == "__main__":
    system = MultiBraidSystem()
    results = system.analyze_input(["ASSERT"], ["ASSERT"], ["ASSERT"])
    for r in results:
        print(f"[{r['domain']}] Level: {r['level']}, Score: {r['score']:.2f}")
