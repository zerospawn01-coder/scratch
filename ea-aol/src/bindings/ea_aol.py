"""
EA-AOL Python Bindings

License: BSD-2-Clause
Version: 0.1.0

Python interface to EA-AOL C runtime using ctypes.
This allows PyTorch code to communicate with the EA-AOL control system.
"""

import ctypes
import os
import sys
import json
from pathlib import Path
from typing import Optional, Tuple


# ============================================================================
# C Structure Definitions
# ============================================================================

class EAMetrics(ctypes.Structure):
    """
    Metrics structure matching ea_metrics.h
    """
    _fields_ = [
        ("timestamp_ms", ctypes.c_uint64),
        ("power_w", ctypes.c_double),
        ("temp_c", ctypes.c_double),
        ("freq_mhz", ctypes.c_double),
        ("utilization", ctypes.c_double),
        ("throughput_tps", ctypes.c_double),
        ("latency_ms", ctypes.c_double),
        ("epi_j_per_token", ctypes.c_double),
        ("quality", ctypes.c_double),
    ]


class EAAdvice(ctypes.Structure):
    """
    Control advice from EA-AOL runtime
    """
    _fields_ = [
        ("new_top_k", ctypes.c_int),           # -1 if unchanged
        ("new_freq_mhz", ctypes.c_double),     # -1.0 if unchanged
        ("should_recompile", ctypes.c_int),    # 0 or 1
        ("violation_detected", ctypes.c_int),  # 0 or 1
    ]


# ============================================================================
# EA-AOL Controller
# ============================================================================

class EAAOLController:
    """
    Python interface to EA-AOL C runtime
    
    This class provides a high-level interface for PyTorch code to:
    - Initialize EA-AOL runtime with IR configuration
    - Report metrics (power, throughput, latency)
    - Receive control advice (Top-K, frequency, etc.)
    
    Example:
        controller = EAAOLController("examples/mixtral.ir.json")
        
        # In training/inference loop
        advice = controller.tick(power=185.2, tps=45.0, latency=48.5)
        
        if advice.new_top_k > 0:
            model.set_top_k(advice.new_top_k)
    """
    
    def __init__(
        self, 
        ir_json_path: str,
        lib_path: Optional[str] = None,
        use_simulator: bool = True
    ):
        """
        Initialize EA-AOL controller
        
        Args:
            ir_json_path: Path to IR JSON file
            lib_path: Path to libea_aol.so (auto-detected if None)
            use_simulator: Use physics simulator instead of real hardware
        """
        # Find library
        if lib_path is None:
            lib_path = self._find_library()
        
        if not os.path.exists(lib_path):
            raise FileNotFoundError(
                f"EA-AOL library not found at {lib_path}. "
                f"Run 'make' to build the library."
            )
        
        print(f"[EA-AOL] Loading library from {lib_path}")
        
        # Load library
        self.lib = ctypes.CDLL(os.path.abspath(lib_path))
        
        # Define function signatures
        self._define_signatures()
        
        # Initialize runtime
        if not os.path.exists(ir_json_path):
            raise FileNotFoundError(f"IR file not found: {ir_json_path}")
        
        print(f"[EA-AOL] Loading IR from {ir_json_path}")
        
        # Set environment variable for simulator mode
        if use_simulator:
            os.environ['EA_AOL_MODE'] = 'SIMULATOR'
            print("[EA-AOL] Using physics simulator")
        
        # Initialize (simplified for v0.1 - just store path)
        self.ir_path = ir_json_path
        self.ctx = None  # Will be initialized on first tick
        self.initialized = False
        
        print("[EA-AOL] Controller initialized")
    
    def _find_library(self) -> str:
        """Auto-detect library path"""
        # Try common locations
        candidates = [
            "build/libea_aol.so",
            "build/libea_aol.dll",
            "runtime/build/libea_aol.so",
            "../build/libea_aol.so",
        ]
        
        for path in candidates:
            if os.path.exists(path):
                return path
        
        raise FileNotFoundError(
            "Could not find EA-AOL library. "
            "Please specify lib_path or run 'make' to build."
        )
    
    def _define_signatures(self):
        """Define C function signatures"""
        # For v0.1, we'll use simplified interface
        # In production, these would match actual C functions
        pass
    
    def tick(
        self, 
        power: float = 0.0,
        throughput_tps: float = 0.0,
        latency_ms: float = 0.0,
        quality: float = 1.0
    ) -> EAAdvice:
        """
        Report metrics and get control advice
        
        Args:
            power: Current power consumption (W)
            throughput_tps: Current throughput (tokens/second)
            latency_ms: Current latency (milliseconds)
            quality: Current quality score [0.0, 1.0]
        
        Returns:
            EAAdvice with control recommendations
        """
        # For v0.1, we'll simulate the advice based on simple rules
        # In production, this would call C runtime
        
        advice = EAAdvice()
        advice.new_top_k = -1  # No change
        advice.new_freq_mhz = -1.0  # No change
        advice.should_recompile = 0
        advice.violation_detected = 0
        
        # Simple rule: if power > 180W, reduce Top-K
        if power > 180.0:
            advice.new_top_k = 4  # Reduce from 8 to 4
            advice.violation_detected = 1
            print(f"[EA-AOL] ⚠️  Power violation: {power:.1f}W > 180W")
            print(f"[EA-AOL] 🔧 Advice: Reduce Top-K to {advice.new_top_k}")
        
        # Simple rule: if latency > 50ms, increase frequency
        elif latency_ms > 50.0:
            advice.new_freq_mhz = 2000.0  # Max frequency
            advice.violation_detected = 1
            print(f"[EA-AOL] ⚠️  Latency violation: {latency_ms:.1f}ms > 50ms")
            print(f"[EA-AOL] 🔧 Advice: Increase frequency to {advice.new_freq_mhz:.0f}MHz")
        
        return advice
    
    def get_current_k(self) -> int:
        """Get current Top-K value"""
        # For v0.1, return default
        return 8
    
    def shutdown(self):
        """Shutdown EA-AOL runtime"""
        if self.ctx:
            # In production: self.lib.ea_aol_destroy(self.ctx)
            pass
        
        print("[EA-AOL] Controller shutdown")
    
    def __del__(self):
        """Cleanup on destruction"""
        self.shutdown()
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.shutdown()


# ============================================================================
# Utility Functions
# ============================================================================

def load_ir(ir_path: str) -> dict:
    """
    Load IR JSON file
    
    Args:
        ir_path: Path to IR JSON file
    
    Returns:
        Parsed IR dictionary
    """
    with open(ir_path, 'r') as f:
        return json.load(f)


def get_power_cap(ir_path: str) -> float:
    """
    Get power cap from IR file
    
    Args:
        ir_path: Path to IR JSON file
    
    Returns:
        Power cap in Watts
    """
    ir = load_ir(ir_path)
    return ir.get('constraints', {}).get('power_cap_w', 180.0)


def get_latency_slo(ir_path: str) -> float:
    """
    Get latency SLO from IR file
    
    Args:
        ir_path: Path to IR JSON file
    
    Returns:
        Latency SLO in milliseconds
    """
    ir = load_ir(ir_path)
    return ir.get('constraints', {}).get('latency_slo_ms', 50.0)


# ============================================================================
# Example Usage
# ============================================================================

if __name__ == '__main__':
    print("="*60)
    print("EA-AOL Python Bindings Test")
    print("="*60 + "\n")
    
    # Initialize controller
    try:
        controller = EAAOLController(
            ir_json_path="output/mixtral_secure.ir.json",
            use_simulator=True
        )
    except FileNotFoundError as e:
        print(f"Error: {e}")
        print("\nPlease ensure:")
        print("1. IR file exists: output/mixtral_secure.ir.json")
        print("2. Run compiler: python src/compiler/ir_compiler.py examples/mixtral_eco.yaml -o output/mixtral_secure.ir.json")
        sys.exit(1)
    
    print("\n" + "="*60)
    print("Simulating inference loop...")
    print("="*60 + "\n")
    
    # Simulate inference loop
    import time
    import random
    
    power = 150.0
    tps = 45.0
    latency = 48.0
    current_k = 8
    
    for i in range(10):
        print(f"\n--- Iteration {i+1} ---")
        
        # Simulate power spike
        if i == 3:
            power = 195.0  # Spike!
            print("🔥 Simulating power spike!")
        
        # Report metrics
        print(f"Metrics: Power={power:.1f}W, TPS={tps:.1f}, Latency={latency:.1f}ms, k={current_k}")
        
        # Get advice
        advice = controller.tick(
            power=power,
            throughput_tps=tps,
            latency_ms=latency
        )
        
        # Apply advice
        if advice.new_top_k > 0 and advice.new_top_k != current_k:
            print(f"✓ Applying advice: Top-K {current_k} → {advice.new_top_k}")
            current_k = advice.new_top_k
            
            # Simulate power reduction
            power = power * 0.6  # ~40% reduction
            tps = tps * 1.2  # ~20% throughput increase
        
        # Random fluctuation
        power += random.uniform(-5, 5)
        tps += random.uniform(-2, 2)
        latency += random.uniform(-1, 1)
        
        time.sleep(0.5)
    
    print("\n" + "="*60)
    print("Test complete")
    print("="*60)
    
    controller.shutdown()
