"""
EA-AOL Compiler - IR Builder Module
Generates Intermediate Representation from parsed declarations
"""

import json
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from .parser import ParsedDeclaration


@dataclass
class Transform:
    """IR Transform specification"""
    id: str
    params: Dict[str, Any]


@dataclass
class Placement:
    """IR Placement specification"""
    host: str
    partitions: List[Dict[str, Any]]


@dataclass
class ControlAction:
    """IR Control action"""
    type: str
    target: str
    params: Dict[str, Any]


@dataclass
class ControlPlan:
    """IR Control plan"""
    time_window_ms: int
    actions: List[ControlAction]


@dataclass
class FeedbackHook:
    """IR Feedback hook"""
    metric: str
    condition: str
    action: str


@dataclass
class EA_IR:
    """EA-AOL Intermediate Representation"""
    meta: Dict[str, Any]
    constraints: Dict[str, float]
    cost_models: Dict[str, Any]
    transforms: List[Transform]
    placement: List[Placement]
    control_plan: List[ControlPlan]
    feedback_hooks: List[FeedbackHook]
    
    def to_json(self) -> str:
        """Serialize IR to JSON"""
        return json.dumps(asdict(self), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'EA_IR':
        """Deserialize IR from JSON"""
        data = json.loads(json_str)
        
        # Reconstruct nested dataclasses
        data['transforms'] = [Transform(**t) for t in data['transforms']]
        data['placement'] = [Placement(**p) for p in data['placement']]
        
        control_plans = []
        for cp in data['control_plan']:
            actions = [ControlAction(**a) for a in cp['actions']]
            control_plans.append(ControlPlan(
                time_window_ms=cp['time_window_ms'],
                actions=actions
            ))
        data['control_plan'] = control_plans
        
        data['feedback_hooks'] = [FeedbackHook(**h) for h in data['feedback_hooks']]
        
        return cls(**data)


class IRBuilder:
    """Builds EA_IR from ParsedDeclaration"""
    
    VERSION = "0.1.0"
    
    def __init__(self):
        self.energy_model = self._default_energy_model
    
    def build(self, decl: ParsedDeclaration) -> EA_IR:
        """Build IR from parsed declaration"""
        
        # Extract constraints
        constraints = self._extract_constraints(decl.inference)
        
        # Build cost models
        cost_models = self._build_cost_models(decl.profile)
        
        # Plan transformations
        transforms = self._plan_transforms(decl.inference, constraints)
        
        # Plan placement
        placement = self._plan_placement(decl.inference, decl.runtime)
        
        # Generate control plan
        control_plan = self._generate_control_plan(
            decl.inference, constraints, transforms
        )
        
        # Setup feedback hooks
        feedback_hooks = self._setup_feedback_hooks(decl.inference, decl.policy)
        
        return EA_IR(
            meta={
                'model_id': decl.inference['model_id'],
                'created_at': datetime.utcnow().isoformat(),
                'compiler_version': self.VERSION
            },
            constraints=constraints,
            cost_models=cost_models,
            transforms=transforms,
            placement=placement,
            control_plan=control_plan,
            feedback_hooks=feedback_hooks
        )
    
    def _extract_constraints(self, inference: Dict[str, Any]) -> Dict[str, float]:
        """Extract constraints from inference section"""
        power_cap = inference['power_cap']
        if isinstance(power_cap, str):
            power_cap = float(power_cap.rstrip('W'))
        
        return {
            'power_cap_w': float(power_cap),
            'latency_slo_ms': float(inference['latency_slo_ms']),
            'quality_floor': float(inference['quality_floor'])
        }
    
    def _build_cost_models(self, profile: Optional[Dict[str, Any]]) -> Dict[str, Any]:
        """Build cost models from profile section"""
        if not profile or 'model_cost' not in profile:
            return {
                'flop_per_token': 1.0e9,  # Default 1 GFLOP
                'mem_bw_per_token': 1000.0,  # Default 1000 MB
                'energy_model': 'default'
            }
        
        model_cost = profile['model_cost']
        flop_value = model_cost.get('flop_per_token', 1.0e9)
        # Ensure flop_per_token is float
        if isinstance(flop_value, str):
            flop_value = float(flop_value)
        
        return {
            'flop_per_token': float(flop_value),
            'mem_bw_per_token': self._parse_memory(
                model_cost.get('mem_bw_per_token', '1000MB')
            ),
            'energy_model': 'default'
        }
    
    def _plan_transforms(
        self, 
        inference: Dict[str, Any], 
        constraints: Dict[str, float]
    ) -> List[Transform]:
        """Plan model transformations"""
        transforms = []
        
        orchestrator = inference.get('orchestrator', {})
        layers = orchestrator.get('layers', [])
        
        power_budget = constraints['power_cap_w']
        
        for layer in layers:
            if layer == 'sparse':
                transforms.append(Transform(
                    id='sparse_layer_prune',
                    params={
                        'sparsity_target': 0.5,
                        'layer_indices': 'auto'
                    }
                ))
            elif layer == 'moe':
                transforms.append(Transform(
                    id='moe_routing_power_aware',
                    params={
                        'budget_w': power_budget * 0.8,
                        'k_max': 4
                    }
                ))
            elif layer == 'cache_compress':
                transforms.append(Transform(
                    id='kv_cache_compression',
                    params={
                        'compression_ratio': 0.5
                    }
                ))
        
        # Add DVFS plan
        dvfs_granularity = orchestrator.get('dvfs_granularity', 'batch')
        transforms.append(Transform(
            id='dvfs_plan',
            params={
                'granularity': dvfs_granularity,
                'base_freq_mhz': 1200,
                'boost_freq_mhz': 1500
            }
        ))
        
        return transforms
    
    def _plan_placement(
        self, 
        inference: Dict[str, Any], 
        runtime: Optional[Dict[str, Any]]
    ) -> List[Placement]:
        """Plan model placement"""
        target_hardware = 'nv_gpu_single'
        if runtime:
            target_hardware = runtime.get('target_hardware', 'nv_gpu_single')
        
        if target_hardware == 'nv_gpu_single':
            return [Placement(
                host='gpu0',
                partitions=[{
                    'layers': 'all',
                    'memory': 'gpu_vram'
                }]
            )]
        else:
            # Default placement
            return [Placement(
                host='gpu0',
                partitions=[{'layers': 'all', 'memory': 'gpu_vram'}]
            )]
    
    def _generate_control_plan(
        self,
        inference: Dict[str, Any],
        constraints: Dict[str, float],
        transforms: List[Transform]
    ) -> List[ControlPlan]:
        """Generate physical control plan"""
        orchestrator = inference.get('orchestrator', {})
        
        actions = []
        
        # GPU frequency control
        for transform in transforms:
            if transform.id == 'dvfs_plan':
                actions.append(ControlAction(
                    type='set_gpu_freq',
                    target='gpu0',
                    params={'freq_mhz': transform.params['base_freq_mhz']}
                ))
        
        # PSU mode (mock for v0.1)
        cooling = orchestrator.get('cooling', 'air')
        if cooling in ['liquid_dynamic', 'immersed']:
            actions.append(ControlAction(
                type='set_psu_mode',
                target='psu0',
                params={'mode': 'burst_absorb'}
            ))
        
        return [ControlPlan(
            time_window_ms=10,
            actions=actions
        )]
    
    def _setup_feedback_hooks(
        self,
        inference: Dict[str, Any],
        policy: Optional[Dict[str, Any]]
    ) -> List[FeedbackHook]:
        """Setup feedback hooks for monitoring"""
        hooks = []
        
        # EPI monitoring
        orchestrator = inference.get('orchestrator', {})
        monitoring = orchestrator.get('monitoring', ['EPI'])
        
        if 'EPI' in monitoring:
            hooks.append(FeedbackHook(
                metric='EPI',
                condition='deviation > 5%',
                action='recompile'
            ))
        
        # Temperature monitoring
        if 'TEMP_MAP' in monitoring:
            hooks.append(FeedbackHook(
                metric='TEMP_MAP.gpu0_die',
                condition='> 85C',
                action='throttle'
            ))
        
        # Power monitoring
        hooks.append(FeedbackHook(
            metric='POWER_W',
            condition=f"> {inference['power_cap']}",
            action='emergency_throttle'
        ))
        
        return hooks
    
    def _parse_memory(self, mem_str: Any) -> float:
        """Parse memory value with units"""
        if isinstance(mem_str, (int, float)):
            return float(mem_str)
        
        mem_str = str(mem_str).strip().upper()
        
        if mem_str.endswith('GB'):
            return float(mem_str[:-2]) * 1024
        elif mem_str.endswith('MB'):
            return float(mem_str[:-2])
        else:
            return float(mem_str)
    
    def _default_energy_model(self, freq_mhz: float, bw_gb_s: float, flops: float) -> float:
        """Default energy model: E = α*F + β*BW + γ*FLOPS"""
        alpha = 0.05  # Frequency coefficient
        beta = 0.03   # Bandwidth coefficient
        gamma = 0.02  # Compute coefficient
        
        return alpha * freq_mhz + beta * bw_gb_s + gamma * flops


def build_ir(decl: ParsedDeclaration) -> EA_IR:
    """Convenience function to build IR"""
    builder = IRBuilder()
    return builder.build(decl)


if __name__ == '__main__':
    from .parser import parse_ea_aol
    
    test_yaml = """
inference:
  model_id: "llama-13b"
  power_cap: 150W
  latency_slo_ms: 20
  quality_floor: 0.95
  orchestrator:
    layers: ["sparse", "moe"]
    dvfs_granularity: "token"
    monitoring: ["EPI", "TEMP_MAP"]
"""
    
    decl = parse_ea_aol(test_yaml)
    ir = build_ir(decl)
    
    print("✓ IR built successfully")
    print(f"  Transforms: {len(ir.transforms)}")
    print(f"  Feedback hooks: {len(ir.feedback_hooks)}")
    print("\nIR JSON:")
    print(ir.to_json())
