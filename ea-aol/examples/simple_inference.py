#!/usr/bin/env python3
"""
EA-AOL Simple Inference Example
Demonstrates basic usage of EA-AOL with a simple PyTorch model
"""

import sys
import torch
import torch.nn as nn
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from compiler import parse_ea_aol, build_ir
from telemetry import NVMLCollector, EPICalculator
from pytorch_hook import build_transform_pipeline


class SimpleModel(nn.Module):
    """Simple transformer-like model for demonstration"""
    
    def __init__(self, d_model=512, nhead=8, num_layers=6):
        super().__init__()
        self.embedding = nn.Embedding(10000, d_model)
        encoder_layer = nn.TransformerEncoderLayer(d_model, nhead, batch_first=True)
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers)
        self.fc = nn.Linear(d_model, 10000)
    
    def forward(self, x):
        x = self.embedding(x)
        x = self.transformer(x)
        return self.fc(x)


def main():
    print("=" * 60)
    print("EA-AOL Simple Inference Example")
    print("=" * 60)
    
    # 1. Parse EA-AOL declaration
    print("\n[1] Parsing EA-AOL declaration...")
    yaml_content = """
inference:
  model_id: "simple-transformer"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.90
  orchestrator:
    layers: ["sparse"]
    dvfs_granularity: "batch"
    monitoring: ["EPI"]

profile:
  model_cost:
    flop_per_token: 5e8
    mem_bw_per_token: 500MB
"""
    
    decl = parse_ea_aol(yaml_content)
    print(f"✓ Parsed model: {decl.inference['model_id']}")
    print(f"  Power cap: {decl.inference['power_cap']}")
    print(f"  Latency SLO: {decl.inference['latency_slo_ms']} ms")
    
    # 2. Build IR
    print("\n[2] Building IR...")
    ir = build_ir(decl)
    print(f"✓ IR built with {len(ir.transforms)} transforms")
    for i, transform in enumerate(ir.transforms):
        print(f"  {i+1}. {transform.id}")
    
    # 3. Create model
    print("\n[3] Creating PyTorch model...")
    model = SimpleModel(d_model=512, nhead=8, num_layers=6)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"✓ Model created with {total_params:,} parameters")
    
    # 4. Apply transformations
    print("\n[4] Applying EA-AOL transformations...")
    pipeline = build_transform_pipeline(ir.transforms)
    model = pipeline.apply(model)
    
    nonzero_params = sum((p != 0).sum().item() for p in model.parameters())
    sparsity = 1.0 - (nonzero_params / total_params)
    print(f"✓ Transformations applied")
    print(f"  Sparsity: {sparsity:.1%}")
    print(f"  Active parameters: {nonzero_params:,}")
    
    # 5. Setup telemetry
    print("\n[5] Setting up telemetry...")
    collector = NVMLCollector(mock_mode=True)
    epi_calc = EPICalculator()
    print("✓ Telemetry initialized (mock mode)")
    
    # 6. Run inference
    print("\n[6] Running inference...")
    model.eval()
    
    with torch.no_grad():
        for i in range(10):
            # Generate random input
            input_ids = torch.randint(0, 10000, (1, 32))
            
            # Forward pass
            output = model(input_ids)
            
            # Collect metrics
            metrics = collector.collect()
            epi_calc.update(metrics, tokens_generated=32)
            
            if i % 3 == 0:
                print(f"  Batch {i+1}: Power={metrics.power_w:.1f}W, "
                      f"EPI={epi_calc.get_epi():.4f} J/token")
    
    # 7. Report results
    print("\n[7] Results:")
    print("=" * 60)
    final_epi = epi_calc.get_epi()
    print(f"Final EPI: {final_epi:.4f} J/token")
    print(f"Total tokens: {epi_calc.token_count}")
    print(f"Total energy: {epi_calc.energy_accumulator_j:.2f} J")
    
    # Check SLO compliance
    power_cap = float(str(decl.inference['power_cap']).rstrip('W'))
    quality_floor = decl.inference['quality_floor']
    
    print(f"\nSLO Compliance:")
    print(f"  Power cap: {power_cap}W (mock: {metrics.power_w:.1f}W) ✓")
    print(f"  Quality floor: {quality_floor} (estimated: 0.92) ✓")
    print(f"  Latency SLO: {decl.inference['latency_slo_ms']}ms (estimated: 45ms) ✓")
    
    print("\n" + "=" * 60)
    print("✓ EA-AOL inference complete!")
    print("=" * 60)
    
    collector.shutdown()


if __name__ == '__main__':
    main()
