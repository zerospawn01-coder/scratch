import json
import os
import logging
from typing import Dict, Any, List, Optional

# --- Configuration & Logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("PHYSICS_SENTINEL")

class PhysicsSentinel:
    """
    Professional-Grade Sentinel Agent for Monitoring Physical Invariants.
    
    Design Rationale:
    - Veracity: Audits physical observations against topological skeletons.
    - Safety: Detects 'Ruptures' in phase transition invariants.
    - Observability: Formal logging of H1 persistence metrics.
    """
    
    def __init__(self, version: str = "1.1.0_hardened"):
        self.version: str = version
        self.name: str = "PHYSICS_SENTINEL"
        self.target_invariants: List[str] = ["Nematicity", "Superconductivity_PH"]
        self.state: str = "INIT"
        self.log_path: str = "C:/Users/zeros/.gemini/antigravity/scratch/mtp_weaver/sentinel_logs.json"

    def _validate_observation_data(self, data: Any) -> None:
        """
        Validates the structure of physical observation data.
        Expects a dictionary with required metrics.
        """
        if not isinstance(data, dict):
            logger.error("Input Violation: Observation data must be a dictionary.")
            raise TypeError("Observation data must be a dictionary.")
        
        required_metrics = ["h1_persistence", "distortion"]
        for metric in required_metrics:
            if metric not in data:
                logger.error(f"Missing Key: '{metric}' is required for physical audit.")
                raise KeyError(f"Missing required metric: {metric}")

    def audit_physical_state(self, observation_data: Dict[str, float]) -> Dict[str, Any]:
        """
        Audit a physical observation against the Invariant Skeleton.
        Returns a formal report of physical stability.
        """
        try:
            self._validate_observation_data(observation_data)
            logger.info("Starting Physical Invariant Audit...")

            # Extract metrics with fail-safe defaults
            h1_persistence: float = float(observation_data.get("h1_persistence", 0.0))
            distortion_score: float = float(observation_data.get("distortion", 0.0))
            
            # Topological Integrity Check:
            # Low persistence (H1 cycles disappearing) or high distortion indicates a structural rupture.
            status: str = "STABLE"
            if h1_persistence < 0.1 or distortion_score > 0.5:
                status = "RUPTURE"
                logger.warning(f"Structural Rupture detected! Persistence: {h1_persistence}, Distortion: {distortion_score}")
                
            report = {
                "agent": self.name,
                "version": self.version,
                "status": status,
                "h1_persistence": h1_persistence,
                "distortion": distortion_score,
                "silent_gate_triggered": status == "RUPTURE"
            }
            
            self._log_report(report)
            return report

        except Exception as e:
            logger.error(f"Physical Audit Aborted: {e}")
            return {"status": "ERROR", "error": str(e)}

    def _log_report(self, report: Dict[str, Any]) -> None:
        """
        Safely logs the audit results to the persistent Sentinel store.
        """
        try:
            logs: List[Dict[str, Any]] = []
            if os.path.exists(self.log_path):
                with open(self.log_path, 'r', encoding='utf-8') as f:
                    try:
                        logs = json.load(f)
                    except json.JSONDecodeError:
                        logger.warning("Sentinel log corrupted. Re-initializing.")
            
            logs.append(report)
            # Limit history to 15 entries
            if len(logs) > 15:
                logs = logs[-15:]
                
            with open(self.log_path, 'w', encoding='utf-8') as f:
                json.dump(logs, f, indent=4)
        except IOError as e:
            logger.error(f"Failed to update Sentinel log: {e}")

if __name__ == "__main__":
    # --- Professional Unit Test ---
    logger.info("Initializing Physics Sentinel validation...")
    sentinel = PhysicsSentinel()
    
    # Test case: Stable observation
    test_data = {"h1_persistence": 0.25, "distortion": 0.02}
    result = sentinel.audit_physical_state(test_data)
    
    print("\n--- PHYSICAL AUDIT VERDICT ---")
    print(json.dumps(result, indent=4))
