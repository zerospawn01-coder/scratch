"""
EA-AOL Compiler - Complete Implementation
Compiles EA-AOL YAML to EA-IR JSON

License: BSD-2-Clause
Version: 0.1.0
"""

import yaml
import json
import sys
import hashlib
from datetime import datetime
from typing import Dict, Any, List, Optional
from pathlib import Path


class CompilerError(Exception):
    """Compiler error exception"""
    pass


class EAAOLCompiler:
    """EA-AOL to EA-IR compiler"""
    
    VERSION = "0.1.0"
    
    def __init__(self):
        self.errors = []
        self.warnings = []
    
    def compile(self, yaml_path: str) -> str:
        """
        Compile EA-AOL YAML file to EA-IR JSON
        
        Args:
            yaml_path: Path to EA-AOL YAML file
            
        Returns:
            EA-IR JSON string
            
        Raises:
            CompilerError: If compilation fails
        """
        # Read and parse YAML
        try:
            with open(yaml_path, 'r', encoding='utf-8') as f:
                source = f.read()
            spec = yaml.safe_load(source)
        except FileNotFoundError:
            raise CompilerError(f"File not found: {yaml_path}")
        except yaml.YAMLError as e:
            raise CompilerError(f"Invalid YAML: {e}")
        
        # Validate structure
        self._validate_structure(spec)
        
        # Generate IR
        ir = self._generate_ir(spec, source)
        
        # Validate IR
        self._validate_ir(ir)
        
        return json.dumps(ir, indent=2)
    
    def _validate_structure(self, spec: Dict[str, Any]):
        """Validate EA-AOL structure"""
        if 'inference' not in spec:
            raise CompilerError("Missing required 'inference' block")
        
        inf = spec['inference']
        required = ['model_id', 'power_cap', 'latency_slo_ms', 'quality_floor']
        
        for field in required:
            if field not in inf:
                raise CompilerError(f"Missing required field: inference.{field}")
        
        # Type validation
        if not isinstance(inf['model_id'], str) or not inf['model_id'].strip():
            raise CompilerError("inference.model_id must be non-empty string")
        
        power_cap = self._parse_power(inf['power_cap'])
        if power_cap <= 0:
            raise CompilerError("inference.power_cap must be positive")
        
        if not isinstance(inf['latency_slo_ms'], (int, float)) or inf['latency_slo_ms'] <= 0:
            raise CompilerError("inference.latency_slo_ms must be positive number")
        
        if not isinstance(inf['quality_floor'], (int, float)) or not (0 <= inf['quality_floor'] <= 1):
            raise CompilerError("inference.quality_floor must be in range [0, 1]")
    
    def _generate_ir(self, spec: Dict[str, Any], source: str) -> Dict[str, Any]:
        """Generate EA-IR from validated spec"""
        inf = spec['inference']
        profile = spec.get('profile', {})
        policy = spec.get('policy', {})
        runtime = spec.get('runtime', {})
        
        # Extract constraints
        constraints = {
            'power_cap_w': self._parse_power(inf['power_cap']),
            'latency_slo_ms': float(inf['latency_slo_ms']),
            'quality_floor': float(inf['quality_floor'])
        }
        
        # Build cost models
        cost_models = self._build_cost_models(profile)
        
        # Plan transforms
        transforms = self._plan_transforms(inf, constraints, profile)
        
        # Plan resources
        resources = self._plan_resources(inf, runtime)
        
        # Generate control plan
        control_plan = self._generate_control_plan(inf, transforms)
        
        # Setup feedback loop
        feedback_loop = self._setup_feedback_loop(inf, policy, constraints)
        
        # Build complete IR
        ir = {
            'ir_version': '0.1.0',
            'meta': {
                'model_id': inf['model_id'],
                'created_at': datetime.utcnow().isoformat() + 'Z',
                'compiler_version': self.VERSION,
                'source_hash': 'sha256:' + hashlib.sha256(source.encode()).hexdigest()[:16]
            },
            'constraints': constraints,
            'cost_models': cost_models,
            'execution_plan': {
                'transforms': transforms,
                'resources': resources,
                'control_plan': control_plan
            },
            'feedback_loop': feedback_loop,
            'optimization_hints': {
                'prefer': policy.get('prefer', ['min_energy']),
                'hard_constraints': policy.get('hard_constraints', ['power_cap', 'latency_slo_ms']),
                'soft_constraints': policy.get('soft_constraints', [])
            }
        }
        
        return ir
    
    def _build_cost_models(self, profile: Dict[str, Any]) -> Dict[str, Any]:
        """Build cost models from profile"""
        model_cost = profile.get('model_cost', {})
        
        flop_per_token = model_cost.get('flop_per_token', 1.0e9)
        if isinstance(flop_per_token, str):
            flop_per_token = float(flop_per_token)
        
        mem_bw = model_cost.get('mem_bw_per_token', '1000MB')
        if isinstance(mem_bw, str):
            mem_bw = self._parse_memory(mem_bw)
        
        return {
            'flop_per_token': float(flop_per_token),
            'mem_bw_per_token': float(mem_bw),
            'energy_model': 'default',
            'baseline_epi': profile.get('baseline_epi', 0.15)
        }
    
    def _plan_transforms(
        self, 
        inf: Dict[str, Any], 
        constraints: Dict[str, float],
        profile: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Plan model transformations based on constraints"""
        transforms = []
        priority = 1
        
        orchestrator = inf.get('orchestrator', {})
        layers = orchestrator.get('layers', [])
        
        power_budget = constraints['power_cap_w']
        
        # Transform selection logic
        for layer in layers:
            if layer == 'sparse':
                transforms.append({
                    'id': 'sparse_layer_prune',
                    'priority': priority,
                    'params': {
                        'sparsity_target': 0.5,
                        'target_layers': ['attn_.*', 'mlp_.*'],
                        'method': 'magnitude'
                    }
                })
                priority += 1
            
            elif layer == 'moe':
                transforms.append({
                    'id': 'moe_routing_power_aware',
                    'priority': priority,
                    'params': {
                        'budget_w': power_budget * 0.8,
                        'k_max': 4,
                        'routing_strategy': 'energy_aware'
                    }
                })
                priority += 1
            
            elif layer == 'cache_compress':
                transforms.append({
                    'id': 'kv_cache_compression',
                    'priority': priority,
                    'params': {
                        'compression_ratio': 0.5,
                        'algorithm': 'quantize_int8'
                    }
                })
                priority += 1
            
            elif layer == 'quantize':
                transforms.append({
                    'id': 'quantize',
                    'priority': priority,
                    'params': {
                        'bits': 4,
                        'group_size': 128
                    }
                })
                priority += 1
        
        # Always add DVFS plan
        dvfs_granularity = orchestrator.get('dvfs_granularity', 'batch')
        transforms.append({
            'id': 'dvfs_plan',
            'priority': 99,
            'params': {
                'granularity': dvfs_granularity,
                'base_freq_mhz': 1200,
                'boost_freq_mhz': 1500,
                'schedule': [
                    {'token_range': [0, 10], 'freq_mhz': 1500},
                    {'token_range': [11, 100], 'freq_mhz': 1200}
                ]
            }
        })
        
        return transforms
    
    def _plan_resources(
        self, 
        inf: Dict[str, Any], 
        runtime: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Plan resource allocation"""
        target_hw = runtime.get('target_hardware', 'nv_gpu_single')
        
        if target_hw == 'nv_gpu_single':
            return {
                'gpu_allocation': ['gpu0'],
                'memory_allocation': {
                    'vram_gb': 40,
                    'host_pinned_gb': 8
                },
                'placement': [
                    {
                        'host': 'gpu0',
                        'partitions': [
                            {
                                'layers': 'all',
                                'memory': 'gpu_vram'
                            }
                        ]
                    }
                ]
            }
        else:
            # Default fallback
            return {
                'gpu_allocation': ['gpu0'],
                'memory_allocation': {'vram_gb': 40},
                'placement': [{'host': 'gpu0', 'partitions': [{'layers': 'all', 'memory': 'gpu_vram'}]}]
            }
    
    def _generate_control_plan(
        self, 
        inf: Dict[str, Any], 
        transforms: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Generate physical control plan"""
        orchestrator = inf.get('orchestrator', {})
        cooling = orchestrator.get('cooling', 'air')
        
        actions = []
        
        # GPU frequency control
        for transform in transforms:
            if transform['id'] == 'dvfs_plan':
                actions.append({
                    'type': 'set_gpu_freq',
                    'target': 'gpu0',
                    'params': {'freq_mhz': transform['params']['base_freq_mhz']}
                })
        
        # PSU mode
        if cooling in ['liquid_dynamic', 'immersed']:
            actions.append({
                'type': 'set_psu_mode',
                'target': 'psu0',
                'params': {'mode': 'burst_absorb'}
            })
        
        return [
            {
                'time_window_ms': 10,
                'actions': actions
            }
        ]
    
    def _setup_feedback_loop(
        self, 
        inf: Dict[str, Any], 
        policy: Dict[str, Any],
        constraints: Dict[str, float]
    ) -> Dict[str, Any]:
        """Setup feedback loop configuration"""
        orchestrator = inf.get('orchestrator', {})
        monitoring = orchestrator.get('monitoring', ['EPI'])
        
        metrics = []
        
        if 'EPI' in monitoring or 'J_PER_TOKEN' in monitoring:
            metrics.append({
                'name': 'EPI_J_PER_TOKEN',
                'threshold_high': 0.15,
                'threshold_low': 0.08,
                'action_high': 'recompile',
                'action_low': 'increase_performance'
            })
        
        # Power monitoring (always enabled)
        metrics.append({
            'name': 'POWER_W',
            'threshold_high': constraints['power_cap_w'],
            'action_high': 'emergency_throttle'
        })
        
        if 'TEMP_MAP' in monitoring:
            metrics.append({
                'name': 'TEMP_GPU_DIE_C',
                'threshold_high': 85.0,
                'action_high': 'throttle'
            })
        
        return {
            'enabled': True,
            'metrics': metrics,
            'recompile_limit': 3,
            'evaluation_interval_ms': 5000
        }
    
    def _validate_ir(self, ir: Dict[str, Any]):
        """Validate generated IR"""
        # Basic structural validation
        required_top = ['ir_version', 'meta', 'constraints', 'execution_plan']
        for field in required_top:
            if field not in ir:
                raise CompilerError(f"Generated IR missing required field: {field}")
        
        # Constraint validation
        if ir['constraints']['power_cap_w'] <= 0:
            raise CompilerError("Invalid IR: power_cap_w must be positive")
    
    def _parse_power(self, value: Any) -> float:
        """Parse power value with optional unit"""
        if isinstance(value, (int, float)):
            return float(value)
        
        if isinstance(value, str):
            value = value.strip().upper()
            if value.endswith('W'):
                return float(value[:-1])
            return float(value)
        
        raise CompilerError(f"Invalid power value: {value}")
    
    def _parse_memory(self, value: Any) -> float:
        """Parse memory value with units (returns MB)"""
        if isinstance(value, (int, float)):
            return float(value)
        
        value = str(value).strip().upper()
        
        if value.endswith('GB'):
            return float(value[:-2]) * 1024
        elif value.endswith('MB'):
            return float(value[:-2])
        else:
            return float(value)


def main():
    """CLI entry point"""
    if len(sys.argv) < 2:
        print("Usage: python compiler.py <input.yaml> [output.json]")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        compiler = EAAOLCompiler()
        ir_json = compiler.compile(input_path)
        
        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(ir_json)
            print(f"[OK] Compiled {input_path} -> {output_path}")
        else:
            print(ir_json)
        
        return 0
    
    except CompilerError as e:
        print(f"[ERROR] Compilation failed: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}", file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
