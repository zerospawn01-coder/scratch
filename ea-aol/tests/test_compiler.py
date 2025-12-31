"""
EA-AOL Compiler Tests
"""

import pytest
from compiler import parse_ea_aol, build_ir, ParserError


class TestParser:
    """Test EA-AOL parser"""
    
    def test_valid_minimal(self):
        """Test minimal valid EA-AOL"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.9
"""
        decl = parse_ea_aol(yaml)
        assert decl.inference['model_id'] == 'test-model'
        assert decl.inference['power_cap'] == '100W'
    
    def test_missing_required_key(self):
        """Test missing required key"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
"""
        with pytest.raises(ParserError, match="Missing required keys"):
            parse_ea_aol(yaml)
    
    def test_invalid_quality_floor(self):
        """Test invalid quality_floor value"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 1.5
"""
        with pytest.raises(ParserError, match="between 0.0 and 1.0"):
            parse_ea_aol(yaml)
    
    def test_with_orchestrator(self):
        """Test with orchestrator section"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.9
  orchestrator:
    layers: ["sparse", "moe"]
    dvfs_granularity: "token"
"""
        decl = parse_ea_aol(yaml)
        assert 'orchestrator' in decl.inference
        assert decl.inference['orchestrator']['layers'] == ['sparse', 'moe']


class TestIRBuilder:
    """Test IR builder"""
    
    def test_build_minimal_ir(self):
        """Test building minimal IR"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.9
"""
        decl = parse_ea_aol(yaml)
        ir = build_ir(decl)
        
        assert ir.meta['model_id'] == 'test-model'
        assert ir.constraints['power_cap_w'] == 100.0
        assert ir.constraints['latency_slo_ms'] == 50.0
        assert ir.constraints['quality_floor'] == 0.9
    
    def test_build_with_transforms(self):
        """Test building IR with transforms"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 150W
  latency_slo_ms: 20
  quality_floor: 0.95
  orchestrator:
    layers: ["sparse", "moe", "cache_compress"]
"""
        decl = parse_ea_aol(yaml)
        ir = build_ir(decl)
        
        # Should have 3 transforms + DVFS
        assert len(ir.transforms) == 4
        
        transform_ids = [t.id for t in ir.transforms]
        assert 'sparse_layer_prune' in transform_ids
        assert 'moe_routing_power_aware' in transform_ids
        assert 'kv_cache_compression' in transform_ids
        assert 'dvfs_plan' in transform_ids
    
    def test_ir_serialization(self):
        """Test IR JSON serialization"""
        yaml = """
inference:
  model_id: "test-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.9
"""
        decl = parse_ea_aol(yaml)
        ir = build_ir(decl)
        
        # Serialize to JSON
        json_str = ir.to_json()
        assert 'test-model' in json_str
        assert 'constraints' in json_str
        
        # Deserialize back
        from compiler.ir_builder import EA_IR
        ir2 = EA_IR.from_json(json_str)
        assert ir2.meta['model_id'] == ir.meta['model_id']


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
