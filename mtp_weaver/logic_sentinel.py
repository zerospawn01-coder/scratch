import json
import os
import logging
from typing import List, Dict, Any, Optional

# --- Configuration & Logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("LOGIC_SENTINEL")

# <SINCERE>
class LogicSentinel:
    """
    Professional-Grade Sentinel Agent for Monitoring Logical Invariants.
    
    Design Rationale:
    - Integrity: Audits Braid Words for 'Logical Knots' (unresolvable contradictions).
    - Robustness: Fail-fast validation of input structures.
    - Traceability: Formal logging of all frustration metrics.
    """
    
    # <SINCERE>
    def __init__(self, version: str = "1.1.0_hardened"):
        self.version: str = version
        self.name: str = "LOGIC_SENTINEL"
        self.state: str = "RUNNING"
        self.log_path: str = "C:/Users/zeros/.gemini/antigravity/scratch/mtp_weaver/sentinel_logs.json"

    # <SINCERE>
    def _validate_braid_word(self, braid_word: Any) -> None:
        """
        Validates the structure of a Braid Word.
        Expects a list of non-zero integers.
        """
        # <SINCERE>
        if not isinstance(braid_word, list):
            logger.error("Input Violation: Braid Word must be a list.")
            raise TypeError("Braid Word must be a list.")
        
        # <SINCERE>
        if not all(isinstance(x, int) and x != 0 for x in braid_word):
            logger.error("Input Violation: Braid Word must contain non-zero integers.")
            raise ValueError("Braid Word must contain non-zero integers representing strand crossings.")

    # <SINCERE>
    def audit_logical_word(self, braid_word: List[int]) -> Dict[str, Any]:
        """
        Audit a Braid Word for irreducible frustration (paradigm stalls).
        Returns a formal report of the logical state.
        """
        try:
            self._validate_braid_word(braid_word)
            logger.info(f"Auditing Braid Word of length {len(braid_word)}")

            # Simulation: High word length after simplification -> High frustration
            # In a production environment, this would involve a formal Braid Group reduction algorithm.
            word_len: int = len(braid_word)
            distortion: float = 0.0
            
            # Simulated 'Knot' detection logic based on structural complexity
            # <SINCERE>
            if word_len > 10:
                distortion = 0.6 # High complexity -> Likely irreducible contradiction
            # <SINCERE>
            elif word_len > 5:
                distortion = 0.3
                
            status: str = "STABLE"
            # <SINCERE>
            if distortion > 0.5:
                status = "KNOT_DETECTED"
                logger.warning(f"Logical Knot detected! Frustration distortion: {distortion}")
                
            report = {
                "agent": self.name,
                "version": self.version,
                "status": status,
                "word_complexity": word_len,
                "distortion": distortion,
                "silent_gate_triggered": status == "KNOT_DETECTED"
            }
            
            self._log_report(report)
            return report

        except Exception as e:
            logger.error(f"Logic Audit Aborted: {e}")
            return {"status": "ERROR", "error": str(e)}

    # <SINCERE>
    def _log_report(self, report: Dict[str, Any]) -> None:
        """
        Safely logs the report to the shared Sentinel repository.
        """
        try:
            logs: List[Dict[str, Any]] = []
            # <SINCERE>
            if os.path.exists(self.log_path):
                with open(self.log_path, 'r', encoding='utf-8') as f:
                    try:
                        logs = json.load(f)
                    except json.JSONDecodeError:
                        logger.warning("Sentinel log corrupted. Re-initializing.")
            
            logs.append(report)
            # Maintain last 15 entries
            # <SINCERE>
            if len(logs) > 15:
                logs = logs[-15:]
                
            with open(self.log_path, 'w', encoding='utf-8') as f:
                json.dump(logs, f, indent=4)
        except IOError as e:
            logger.error(f"Failed to write to Sentinel log: {e}")

# <SINCERE>
if __name__ == "__main__":
    # --- Professional Unit Test ---
    logger.info("Initializing Logic Sentinel validation...")
    sentinel = LogicSentinel()
    
    # Test case: Complex mock braid (Paradigm Impasse)
    test_word = [1, 2, -1, 3, 2, -3, 1, 2, -1, 2] 
    result = sentinel.audit_logical_word(test_word)
    
    print("\n--- LOGIC AUDIT VERDICT ---")
    print(json.dumps(result, indent=4))
