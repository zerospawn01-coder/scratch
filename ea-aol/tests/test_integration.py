"""
EA-AOL Integration Tests
End-to-end tests for the complete workflow
"""

import pytest
import torch
import torch.nn as nn
from compiler import parse_ea_aol, build_ir
from telemetry import NVMLCollector, EPICalculator
from pytorch_hook import build_transform_pipeline


class SimpleTestModel(nn.Module):
    """Simple model for testing"""
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(128, 256)
        self.fc2 = nn.Linear(256, 128)
    
    def forward(self, x):
        return self.fc2(torch.relu(self.fc1(x)))


class TestEndToEnd:
    """End-to-end integration tests"""
    
    def test_full_workflow(self):
        """Test complete EA-AOL workflow"""
        # 1. Parse YAML
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.9
  orchestrator:
    layers: ["sparse"]
    monitoring: ["EPI"]
"""
        decl = parse_ea_aol(yaml)
        
        # 2. Build IR
        ir = build_ir(decl)
        assert len(ir.transforms) > 0
        
        # 3. Create model
        model = SimpleTestModel()
        original_params = sum(p.numel() for p in model.parameters())
        
        # 4. Apply transformations
        pipeline = build_transform_pipeline(ir.transforms)
        model = pipeline.apply(model)
        
        # 5. Verify sparsification
        nonzero_params = sum((p != 0).sum().item() for p in model.parameters())
        assert nonzero_params < original_params
        
        # 6. Run inference
        model.eval()
        with torch.no_grad():
            x = torch.randn(1, 128)
            output = model(x)
            assert output.shape == (1, 128)
    
    def test_telemetry_collection(self):
        """Test telemetry collection"""
        collector = NVMLCollector(mock_mode=True)
        calculator = EPICalculator()
        
        # Collect metrics
        for _ in range(5):
            metrics = collector.collect()
            calculator.update(metrics, tokens_generated=10)
            
            assert metrics.power_w > 0
            assert metrics.temp_gpu_die_c > 0
        
        # Verify EPI calculation
        epi = calculator.get_epi()
        assert epi > 0
        assert calculator.token_count == 50
        
        collector.shutdown()
    
    def test_multiple_transforms(self):
        """Test multiple transformations"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 150W
  latency_slo_ms: 20
  quality_floor: 0.95
  orchestrator:
    layers: ["sparse", "moe"]
"""
        decl = parse_ea_aol(yaml)
        ir = build_ir(decl)
        
        model = SimpleTestModel()
        pipeline = build_transform_pipeline(ir.transforms)
        model = pipeline.apply(model)
        
        # Check that MoE flag is set
        assert hasattr(model, '_ea_aol_moe_enabled')
        assert model._ea_aol_moe_enabled == True


class TestErrorHandling:
    """Test error handling"""
    
    def test_invalid_yaml(self):
        """Test invalid YAML handling"""
        from compiler import ParserError
        
        invalid_yaml = """
inference:
  model_id: "test"
  invalid syntax here
"""
        with pytest.raises(ParserError):
            parse_ea_aol(invalid_yaml)
    
    def test_missing_section(self):
        """Test missing inference section"""
        from compiler import ParserError
        
        yaml = """
profile:
  model_cost:
    flop_per_token: 1e9
"""
        with pytest.raises(ParserError, match="Missing required 'inference'"):
            parse_ea_aol(yaml)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
