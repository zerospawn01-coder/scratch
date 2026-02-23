import hashlib
from typing import List, Dict, Any

class SymmetryDetector:
    """
    Prevents 'Dead Logic' by prohibiting repeated patterns in the Trajectory.
    """
    def __init__(self, trajectory):
        self._trajectory = trajectory

    def _get_payload_hash(self, payload: Dict[str, Any]) -> str:
        import json
        payload_str = json.dumps(payload, sort_keys=True)
        return hashlib.sha256(payload_str.encode()).hexdigest()

    def _get_ast_fingerprint(self, code: str) -> str:
        """Returns a normalized AST fingerprint to detect structural mirror-symmetry."""
        import ast
        try:
            tree = ast.parse(code)
            # Strip docstrings and specific names to get the 'shape'
            for node in ast.walk(tree):
                if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
                    node.name = "_"
            return ast.dump(tree)
        except:
            return code # Fallback to raw if not parseable

    def validate(self, new_payload: Dict[str, Any]):
        """Checks for Symmetry and Mirror Loops."""
        trajectory_chain = self._trajectory.chain if hasattr(self._trajectory, 'chain') else self._trajectory
        new_hash = self._get_payload_hash(new_payload)
        
        # 1. Direct Symmetry (REPEATING past thought)
        for entry in trajectory_chain:
            existing_payload = entry.get("payload")
            if existing_payload and self._get_payload_hash(existing_payload) == new_hash:
                raise RuntimeError("ICE_VIOLATION: Symmetry detected. History cannot repeat.")

        # 2. Mirror Symmetry (REVERTING to previous state)
        if len(trajectory_chain) >= 2:
            ancestor_payload = trajectory_chain[-2].get("payload") # N-2 state
            if ancestor_payload:
                new_code = new_payload.get("params", {}).get("code", "")
                old_code = ancestor_payload.get("params", {}).get("code", "")
                if new_code and old_code and self._get_ast_fingerprint(new_code) == self._get_ast_fingerprint(old_code):
                    raise RuntimeError("ICE_VIOLATION: Mirror Symmetry detected. Reverting to previous structural state is prohibited.")

class StructuralEnforcer:
    """
    Enforces the 'Sieve Shadow' invariant (R ≈ 0.7).
    R is calculated as the normalized Shannon Entropy of the payload (H / 8).
    """
    def __init__(self, target_r: float = 0.7):
        self.target_r = target_r

    def calculate_r_value(self, payload: Dict[str, Any]) -> float:
        """Calculates normalized Shannon Entropy."""
        import json
        import math
        from collections import Counter
        
        text = json.dumps(payload)
        if not text: return 0.0
        
        counts = Counter(text)
        total = len(text)
        entropy = -sum((count/total) * math.log2(count/total) for count in counts.values())
        
        # Normalized: H / 8 (for 8-bit bytes)
        return min(1.0, entropy / 8.0)

    def validate(self, payload: Dict[str, Any], current_legr: float = 0.0):
        r = self.calculate_r_value(payload)
        
        # Dynamic Sieve: R_min increases if the system LEGR is stagnating
        # If legr is low (< 0.5), we raise the bar to force higher-entropy mutation
        dynamic_min = 0.45 if current_legr > 0.6 else 0.65
        
        # Gates based on Sieve Shadow Theory
        if r < dynamic_min:
            raise RuntimeError(f"ICE_VIOLATION: Logic is too stable/repetitive (R={r:.2f}, target_min={dynamic_min}). Evolution requires more structural intensity.")
        
        if r > 0.95:
            # Random noise rejection
            raise RuntimeError(f"ICE_VIOLATION: Logic is too chaotic/random (R={r:.2f}). Structure is lost.")

class ThermalEnforcer:
    """
    Prevents 'Control Loss' by blocking hyper-active mutation loops.
    If the agent attempts too many structural changes within a window, the OS halts.
    """
    def __init__(self, window_size: int = 5, limit: float = 3.0):
        self.window_size = window_size
        self.limit = limit # Max average dCRI / dt

    def validate(self, trajectory_chain: List[Dict[str, Any]], new_payload: Dict[str, Any]):
        if len(trajectory_chain) < self.window_size: return
        
        # Calculate recent activity density
        recent = trajectory_chain[-self.window_size:]
        mutation_count = sum(1 for e in recent if "COMMIT" in str(e.get("payload", "")))
        
        if mutation_count >= self.window_size - 1:
            raise RuntimeError("ICE_VIOLATION: Thermal Overload Detected. Hyper-active mutation is prohibited.")

class ICE:
    """The complete Irreversibility Constraint Engine."""
    def __init__(self, trajectory):
        self._trajectory = trajectory
        self.detector = SymmetryDetector(trajectory)
        self.enforcer = StructuralEnforcer()
        self.thermal = ThermalEnforcer()

    def process_vibration(self, payload: Dict[str, Any]):
        """The total gating process."""
        self.detector.validate(payload)
        self.enforcer.validate(payload)
        trajectory_chain = self._trajectory.chain if hasattr(self._trajectory, 'chain') else self._trajectory
        self.thermal.validate(trajectory_chain, payload)
