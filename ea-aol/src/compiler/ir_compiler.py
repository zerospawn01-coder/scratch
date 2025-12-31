#!/usr/bin/env python3
"""
EA-AOL IR Compiler v0.1
Compiles EA-AOL YAML to C-compatible IR JSON

License: BSD-2-Clause
Date: 2025-12-11

This compiler transforms human-readable YAML declarations into
machine-readable IR that the C++ runtime can interpret.
"""

import sys
import yaml
import json
import argparse
from typing import Dict, Any, List
from pathlib import Path


# ============================================================================
# C Header Constants Mappings (Must match ea_ir.h)
# ============================================================================

# Action Types (from ea_ir.h)
ACTION_MAP = {
    "none": 0,              # ACTION_NONE
    "dvfs_scale": 1,        # ACTION_DVFS_SCALE
    "reduce_top_k": 2,      # ACTION_MOE_REDUCE_K
    "moe_reduce_k": 2,      # Alias
    "layer_skip": 3,        # ACTION_LAYER_SKIP
    "batch_resize": 4,      # ACTION_BATCH_RESIZE
    "quantize": 5           # ACTION_QUANTIZE
}

# Comparison Operators
OPERATOR_MAP = {
    ">": ">",
    "<": "<",
    ">=": ">=",
    "<=": "<=",
    "==": "==",
    "!=": "!="
}


# ============================================================================
# Compiler Implementation
# ============================================================================

class IRCompiler:
    """EA-AOL to IR compiler"""
    
    VERSION = "0.1.0"
    
    def __init__(self):
        self.errors = []
        self.warnings = []
    
    def compile(self, source: Dict[str, Any]) -> Dict[str, Any]:
        """
        Compile YAML dict to EA-AOL IR dict
        
        Args:
            source: Parsed YAML dictionary
            
        Returns:
            IR dictionary ready for JSON serialization
        """
        # Validate source structure
        self._validate_source(source)
        
        # Extract sections
        inference = source.get("inference", {})
        profile = source.get("profile", {})
        policy = source.get("policy", {})
        runtime = source.get("runtime", {})
        
        # Build IR components
        meta = self._build_meta(inference)
        constraints = self._build_constraints(inference)
        cost_model = self._build_cost_model(profile)
        rules = self._build_rules(policy, constraints)
        runtime_config = self._build_runtime_config(runtime)
        
        # Construct complete IR
        ir = {
            "ir_version": self.VERSION,
            "meta": meta,
            "constraints": constraints,
            "cost_model": cost_model,
            "metrics_snap": {
                "last_power_w": 0.0,
                "last_latency_ms": 0.0,
                "last_epi_j_per_token": 0.0,
                "timestamp": 0
            },
            "num_rules": len(rules),
            "rules": rules,
            "dvfs_granularity": runtime_config.get("dvfs_granularity", 0),
            "telemetry_interval_ms": runtime_config.get("telemetry_interval_ms", 500),
            "recompile_limit": runtime_config.get("recompile_limit", 3)
        }
        
        return ir
    
    def _validate_source(self, source: Dict[str, Any]):
        """Validate source YAML structure"""
        if "inference" not in source:
            raise CompilerError("Missing required 'inference' block")
        
        inf = source["inference"]
        required_fields = ["model_id", "power_cap", "latency_slo_ms", "quality_floor"]
        
        for field in required_fields:
            if field not in inf:
                raise CompilerError(f"Missing required field: inference.{field}")
    
    def _build_meta(self, inference: Dict[str, Any]) -> Dict[str, Any]:
        """Build metadata section with security validation"""
        import time
        
        model_id = str(inference["model_id"])
        
        # ✅ SECURITY: String length validation (matches C MAX_ID_LEN = 63)
        if len(model_id) > 63:
            raise CompilerError(
                f"Security: model_id exceeds maximum length (63), got {len(model_id)}"
            )
        
        return {
            "model_id": model_id,
            "version": self.VERSION,
            "created_at": int(time.time())
        }
    
    def _build_constraints(self, inference: Dict[str, Any]) -> Dict[str, float]:
        """Build constraints section with security validation"""
        # Parse power_cap (handle "180.0" or "180W" or 180)
        power_cap = inference["power_cap"]
        if isinstance(power_cap, str):
            power_cap = float(power_cap.rstrip('W'))
        else:
            power_cap = float(power_cap)
        
        latency_slo = float(inference["latency_slo_ms"])
        quality_floor = float(inference["quality_floor"])
        
        # ✅ SECURITY: Range validation
        if not (0 < power_cap <= 1000):
            raise CompilerError(
                f"Security: power_cap_w must be in range (0, 1000], got {power_cap}"
            )
        
        if not (0 < latency_slo <= 10000):
            raise CompilerError(
                f"Security: latency_slo_ms must be in range (0, 10000], got {latency_slo}"
            )
        
        if not (0 <= quality_floor <= 1.0):
            raise CompilerError(
                f"Security: quality_floor must be in range [0, 1], got {quality_floor}"
            )
        
        return {
            "power_cap_w": power_cap,
            "latency_slo_ms": latency_slo,
            "quality_floor": quality_floor
        }
    
    def _build_cost_model(self, profile: Dict[str, Any]) -> Dict[str, float]:
        """Build cost model section"""
        cost = profile.get("cost_model", {})
        
        # Parse memory bandwidth (handle "800MB" or 800)
        mem_bw = cost.get("mem_bw_per_token", 0.0)
        if isinstance(mem_bw, str):
            mem_bw = mem_bw.upper()
            if mem_bw.endswith("MB"):
                mem_bw = float(mem_bw[:-2]) * 1024 * 1024  # Convert to bytes
            elif mem_bw.endswith("GB"):
                mem_bw = float(mem_bw[:-2]) * 1024 * 1024 * 1024
            else:
                mem_bw = float(mem_bw)
        else:
            mem_bw = float(mem_bw)
        
        return {
            "flops_per_token": float(cost.get("flops_per_token", 0.0)),
            "mem_bw_per_token": mem_bw,
            "alpha": float(cost.get("alpha_j_per_flop", 1.0e-12)),
            "beta": float(cost.get("beta_j_per_byte", 5.0e-9)),
            "overhead_j": float(cost.get("tau_j_per_token", 0.001))
        }
    
    def _build_rules(
        self, 
        policy: Dict[str, Any], 
        constraints: Dict[str, float]
    ) -> List[Dict[str, Any]]:
        """Build control rules from policy strategies"""
        strategies = policy.get("strategies", [])
        rules = []
        
        for strategy in strategies:
            rule = self._parse_strategy(strategy, constraints)
            if rule:
                rules.append(rule)
        
        return rules
    
    def _parse_strategy(
        self, 
        strategy: Dict[str, Any], 
        constraints: Dict[str, float]
    ) -> Dict[str, Any]:
        """Parse a single strategy into a rule"""
        # Parse trigger: "metric op value"
        trigger = strategy.get("trigger", "")
        
        # Simple parsing for v0.1
        # Expected format: "power > power_cap" or "latency < latency_slo"
        metric_name = "power_w"
        op = ">"
        threshold = 0.0
        
        if "power" in trigger.lower():
            metric_name = "power_w"
            if "power_cap" in trigger:
                threshold = constraints["power_cap_w"]
        elif "latency" in trigger.lower():
            metric_name = "latency_ms"
            if "latency_slo" in trigger or "slo" in trigger:
                threshold = constraints["latency_slo_ms"]
        
        # Parse operator
        for op_str in OPERATOR_MAP.keys():
            if op_str in trigger:
                op = op_str
                break
        
        # Parse action
        action_str = strategy.get("action", "none")
        action_code = ACTION_MAP.get(action_str, 0)
        
        # ✅ SECURITY: Default cooldown to prevent oscillation
        cooldown_ms = strategy.get("cooldown_ms", 2000)  # 2 second default
        
        # Build rule
        rule = {
            "metric_name": metric_name,
            "op": op,
            "threshold": threshold,
            "action": action_code,
            "action_param": float(strategy.get("step", 1.0)),
            "min_value": float(strategy.get("min_k", 1.0)),
            "max_value": float(strategy.get("max_k", 8.0)),
            "cooldown_ms": int(cooldown_ms),
            "last_triggered_ms": 0
        }
        
        return rule
    
    def _build_runtime_config(self, runtime: Dict[str, Any]) -> Dict[str, Any]:
        """Build runtime configuration"""
        # DVFS granularity: batch=0, token=1, layer=2
        dvfs_map = {"batch": 0, "token": 1, "layer": 2}
        dvfs_str = runtime.get("dvfs_granularity", "batch")
        
        return {
            "dvfs_granularity": dvfs_map.get(dvfs_str, 0),
            "telemetry_interval_ms": runtime.get("telemetry_interval_ms", 500),
            "recompile_limit": runtime.get("recompile_limit", 3)
        }


class CompilerError(Exception):
    """Compiler error exception"""
    pass


# ============================================================================
# CLI Interface
# ============================================================================

def parse_args():
    """Parse command-line arguments"""
    parser = argparse.ArgumentParser(
        description="EA-AOL Compiler v0.1 - Compile YAML to IR JSON",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ir_compiler.py input.yaml
  python ir_compiler.py input.yaml -o output.json
  python ir_compiler.py input.yaml --validate-only
        """
    )
    
    parser.add_argument(
        "input_yaml",
        help="Path to source YAML file"
    )
    
    parser.add_argument(
        "-o", "--output",
        default="out.ir.json",
        help="Path to output JSON IR (default: out.ir.json)"
    )
    
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate YAML, don't generate IR"
    )
    
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output"
    )
    
    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_args()
    
    try:
        # Load YAML
        print(f"[Compiler] Loading {args.input_yaml}...")
        with open(args.input_yaml, 'r', encoding='utf-8') as f:
            source_yaml = yaml.safe_load(f)
        
        # Compile
        print(f"[Compiler] Compiling...")
        compiler = IRCompiler()
        ir_dict = compiler.compile(source_yaml)
        
        if args.validate_only:
            print("[Compiler] [OK] Validation successful")
            return 0
        
        # Write output
        print(f"[Compiler] Writing IR to {args.output}...")
        with open(args.output, 'w', encoding='utf-8') as f:
            if args.pretty:
                json.dump(ir_dict, f, indent=2)
            else:
                json.dump(ir_dict, f, indent=2)  # Always pretty for v0.1
        
        print(f"[Compiler] [OK] Success! IR written to {args.output}")
        
        # Print summary
        print(f"\nSummary:")
        print(f"  Model: {ir_dict['meta']['model_id']}")
        print(f"  Power Cap: {ir_dict['constraints']['power_cap_w']} W")
        print(f"  Latency SLO: {ir_dict['constraints']['latency_slo_ms']} ms")
        print(f"  Quality Floor: {ir_dict['constraints']['quality_floor']}")
        print(f"  Rules: {ir_dict['num_rules']}")
        
        return 0
        
    except FileNotFoundError:
        print(f"[Compiler] Error: File not found: {args.input_yaml}", file=sys.stderr)
        return 1
    
    except yaml.YAMLError as e:
        print(f"[Compiler] Error: Invalid YAML: {e}", file=sys.stderr)
        return 1
    
    except CompilerError as e:
        print(f"[Compiler] Error: {e}", file=sys.stderr)
        return 1
    
    except Exception as e:
        print(f"[Compiler] Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 2


if __name__ == "__main__":
    sys.exit(main())
