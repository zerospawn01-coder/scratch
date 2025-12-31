#!/usr/bin/env python3
"""
EA-AOL Demo Script (No Dependencies)
Demonstrates EA-AOL compiler without requiring PyTorch
"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from compiler import parse_ea_aol, build_ir


def main():
    print("=" * 70)
    print("EA-AOL v0.1.0 - Compiler Demo")
    print("=" * 70)
    
    # Example EA-AOL declaration
    yaml_content = """
inference:
  model_id: "llama-2-13b-chat"
  power_cap: 150W
  latency_slo_ms: 25
  quality_floor: 0.93
  
  orchestrator:
    layers:
      - "sparse"
      - "moe"
      - "cache_compress"
    dvfs_granularity: "token"
    cooling: "liquid_dynamic"
    monitoring:
      - "EPI"
      - "J_PER_TOKEN"
      - "TEMP_MAP"

profile:
  model_cost:
    flop_per_token: 1.3e9
    mem_bw_per_token: 1400MB
  baseline_quality: 1.0
  baseline_epi: 0.18

policy:
  prefer:
    - "min_energy"
    - "max_quality"
  hard_constraints:
    - "power_cap"
    - "latency_slo_ms"

runtime:
  target_hardware: "nv_gpu_single"
  telemetry_endpoint: "unix:/var/run/ea_aol.sock"
"""
    
    print("\n[1] Parsing EA-AOL Declaration")
    print("-" * 70)
    
    try:
        decl = parse_ea_aol(yaml_content)
        print("[OK] Parse successful!")
        print(f"\nModel ID: {decl.inference['model_id']}")
        print(f"Power Cap: {decl.inference['power_cap']}")
        print(f"Latency SLO: {decl.inference['latency_slo_ms']} ms")
        print(f"Quality Floor: {decl.inference['quality_floor']}")
        
        if 'orchestrator' in decl.inference:
            orch = decl.inference['orchestrator']
            print(f"\nOrchestrator Layers:")
            for layer in orch.get('layers', []):
                print(f"  - {layer}")
            print(f"DVFS Granularity: {orch.get('dvfs_granularity', 'N/A')}")
            print(f"Cooling: {orch.get('cooling', 'N/A')}")
        
    except Exception as e:
        print(f"[ERROR] Parse failed: {e}")
        return 1
    
    print("\n[2] Building Intermediate Representation (IR)")
    print("-" * 70)
    
    try:
        ir = build_ir(decl)
        print("[OK] IR built successfully!")
        
        print(f"\nMeta:")
        print(f"  Model ID: {ir.meta['model_id']}")
        print(f"  Created: {ir.meta['created_at']}")
        print(f"  Compiler Version: {ir.meta['compiler_version']}")
        
        print(f"\nConstraints:")
        print(f"  Power Cap: {ir.constraints['power_cap_w']} W")
        print(f"  Latency SLO: {ir.constraints['latency_slo_ms']} ms")
        print(f"  Quality Floor: {ir.constraints['quality_floor']}")
        
        print(f"\nCost Models:")
        print(f"  FLOPs/token: {ir.cost_models['flop_per_token']:.2e}")
        print(f"  Memory BW/token: {ir.cost_models['mem_bw_per_token']:.0f} MB")
        
        print(f"\nTransforms ({len(ir.transforms)}):")
        for i, transform in enumerate(ir.transforms, 1):
            print(f"  {i}. {transform.id}")
            for key, value in transform.params.items():
                print(f"     - {key}: {value}")
        
        print(f"\nPlacement ({len(ir.placement)}):")
        for placement in ir.placement:
            print(f"  Host: {placement.host}")
            for partition in placement.partitions:
                print(f"    Partition: {partition}")
        
        print(f"\nControl Plan ({len(ir.control_plan)} windows):")
        for i, plan in enumerate(ir.control_plan, 1):
            print(f"  Window {i} ({plan.time_window_ms}ms):")
            for action in plan.actions:
                print(f"    - {action.type} on {action.target}")
        
        print(f"\nFeedback Hooks ({len(ir.feedback_hooks)}):")
        for hook in ir.feedback_hooks:
            print(f"  - {hook.metric}: {hook.condition} -> {hook.action}")
        
    except Exception as e:
        print(f"[ERROR] IR build failed: {e}")
        return 1
    
    print("\n[3] IR Serialization")
    print("-" * 70)
    
    try:
        json_str = ir.to_json()
        print(f"[OK] IR serialized to JSON ({len(json_str)} bytes)")
        
        # Save to file
        output_file = Path(__file__).parent / "demo_ir.json"
        output_file.write_text(json_str, encoding='utf-8')
        print(f"[OK] Saved to: {output_file}")
        
    except Exception as e:
        print(f"[ERROR] Serialization failed: {e}")
        return 1
    
    print("\n" + "=" * 70)
    print("[OK] EA-AOL Compiler Demo Complete!")
    print("=" * 70)
    print("\nNext Steps:")
    print("  1. Install PyTorch: pip install torch")
    print("  2. Run full example: python examples/simple_inference.py")
    print("  3. Read docs: docs/EA-AOL-v0.1-Specification.md")
    print("  4. Explore examples: examples/llama-13b.yaml")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
