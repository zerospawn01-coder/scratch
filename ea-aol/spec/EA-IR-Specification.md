# EA-IR: EA-AOL Intermediate Representation Specification

**License**: CC0 1.0 Universal (Public Domain)  
**Version**: 0.1.0  
**Date**: 2025-12-11

---

## Overview

EA-IR (Energy-Aware Intermediate Representation) is the compiled form of EA-AOL declarations. The compiler transforms declarative YAML into executable JSON-based IR that the runtime can interpret and execute.

---

## IR Schema (JSON)

### Complete Example

```json
{
  "ir_version": "0.1.0",
  "meta": {
    "model_id": "llama-2-13b-chat",
    "created_at": "2025-12-11T05:00:00Z",
    "compiler_version": "0.1.0",
    "source_hash": "sha256:abc123..."
  },
  "constraints": {
    "power_cap_w": 150.0,
    "latency_slo_ms": 25.0,
    "quality_floor": 0.93
  },
  "cost_models": {
    "flop_per_token": 1.3e9,
    "mem_bw_per_token": 1400.0,
    "energy_model": "default",
    "baseline_epi": 0.18
  },
  "execution_plan": {
    "transforms": [
      {
        "id": "sparse_layer_prune",
        "priority": 1,
        "params": {
          "sparsity_target": 0.5,
          "target_layers": ["attn_.*", "mlp_.*"],
          "method": "magnitude"
        }
      },
      {
        "id": "moe_routing_power_aware",
        "priority": 2,
        "params": {
          "budget_w": 120.0,
          "k_max": 4,
          "routing_strategy": "energy_aware"
        }
      },
      {
        "id": "kv_cache_compression",
        "priority": 3,
        "params": {
          "compression_ratio": 0.5,
          "algorithm": "quantize_int8"
        }
      },
      {
        "id": "dvfs_plan",
        "priority": 4,
        "params": {
          "granularity": "token",
          "base_freq_mhz": 1200,
          "boost_freq_mhz": 1500,
          "schedule": [
            {"token_range": [0, 10], "freq_mhz": 1500},
            {"token_range": [11, 100], "freq_mhz": 1200}
          ]
        }
      }
    ],
    "resources": {
      "gpu_allocation": ["gpu0"],
      "memory_allocation": {
        "vram_gb": 40,
        "host_pinned_gb": 8
      },
      "placement": [
        {
          "host": "gpu0",
          "partitions": [
            {
              "layers": "all",
              "memory": "gpu_vram"
            }
          ]
        }
      ]
    },
    "control_plan": [
      {
        "time_window_ms": 10,
        "actions": [
          {
            "type": "set_gpu_freq",
            "target": "gpu0",
            "params": {"freq_mhz": 1200}
          },
          {
            "type": "set_psu_mode",
            "target": "psu0",
            "params": {"mode": "burst_absorb"}
          }
        ]
      }
    ]
  },
  "feedback_loop": {
    "enabled": true,
    "metrics": [
      {
        "name": "EPI_J_PER_TOKEN",
        "threshold_high": 0.15,
        "threshold_low": 0.08,
        "action_high": "recompile",
        "action_low": "increase_performance"
      },
      {
        "name": "POWER_W",
        "threshold_high": 150.0,
        "action_high": "emergency_throttle"
      },
      {
        "name": "TEMP_GPU_DIE_C",
        "threshold_high": 85.0,
        "action_high": "throttle"
      }
    ],
    "recompile_limit": 3,
    "evaluation_interval_ms": 5000
  },
  "optimization_hints": {
    "prefer": ["min_energy", "max_quality"],
    "hard_constraints": ["power_cap", "latency_slo_ms"],
    "soft_constraints": [
      {
        "name": "temp_limit",
        "value": 80.0,
        "weight": 0.8
      }
    ]
  }
}
```

---

## Field Definitions

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ir_version` | string | Yes | IR format version |
| `meta` | object | Yes | Metadata about compilation |
| `constraints` | object | Yes | Hard constraints from user |
| `cost_models` | object | Yes | Energy and performance models |
| `execution_plan` | object | Yes | Executable transformation plan |
| `feedback_loop` | object | No | Runtime adaptation configuration |
| `optimization_hints` | object | No | Optimization preferences |

### `meta` Object

| Field | Type | Description |
|-------|------|-------------|
| `model_id` | string | Model identifier |
| `created_at` | string (ISO 8601) | Compilation timestamp |
| `compiler_version` | string | Compiler version |
| `source_hash` | string | Hash of source YAML |

### `constraints` Object

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| `power_cap_w` | number | W | Maximum power consumption |
| `latency_slo_ms` | number | ms | Maximum P99 latency |
| `quality_floor` | number | [0,1] | Minimum quality ratio |

### `execution_plan.transforms` Array

Each transform object:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Transform identifier |
| `priority` | number | Execution order (lower = earlier) |
| `params` | object | Transform-specific parameters |

#### Supported Transform IDs

- `sparse_layer_prune`: Magnitude-based pruning
- `moe_routing_power_aware`: Energy-aware MoE routing
- `kv_cache_compression`: KV cache compression
- `dvfs_plan`: Dynamic voltage/frequency scaling
- `quantize`: Model quantization
- `dynamic_batching`: Batch size adaptation

### `feedback_loop.metrics` Array

Each metric object:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Metric identifier |
| `threshold_high` | number | Upper threshold |
| `threshold_low` | number | Lower threshold (optional) |
| `action_high` | string | Action when exceeding high threshold |
| `action_low` | string | Action when below low threshold |

#### Supported Actions

- `recompile`: Trigger IR recompilation
- `throttle`: Reduce performance
- `emergency_throttle`: Immediate power reduction
- `increase_performance`: Boost performance
- `alert`: Send notification only

---

## IR Generation Algorithm

### Compiler Pipeline

```
YAML Source
    ↓
[Parser] → AST
    ↓
[Validator] → Validated AST
    ↓
[Cost Estimator] → Cost Models
    ↓
[Transform Planner] → Transform List
    ↓
[Placement Optimizer] → Resource Allocation
    ↓
[Control Generator] → Control Plan
    ↓
[IR Builder] → EA-IR (JSON)
```

### Transform Selection Logic

```python
def select_transforms(constraints, profile):
    transforms = []
    
    # Energy-critical: Always apply sparse if power_cap < 200W
    if constraints.power_cap_w < 200:
        transforms.append({
            "id": "sparse_layer_prune",
            "priority": 1,
            "params": {"sparsity_target": 0.5}
        })
    
    # Quality-critical: Apply MoE if quality_floor > 0.9
    if constraints.quality_floor > 0.9:
        transforms.append({
            "id": "moe_routing_power_aware",
            "priority": 2,
            "params": {"k_max": 4}
        })
    
    # Always apply DVFS for dynamic adaptation
    transforms.append({
        "id": "dvfs_plan",
        "priority": 99,
        "params": {"granularity": "token"}
    })
    
    return transforms
```

---

## IR Validation Rules

### Structural Validation

1. **Required Fields**: All top-level required fields must be present
2. **Type Checking**: All fields must match specified types
3. **Range Validation**: Numeric values must be within valid ranges

### Semantic Validation

1. **Transform Compatibility**: Transforms must not conflict
2. **Resource Feasibility**: Allocated resources must be available
3. **Constraint Satisfaction**: Execution plan must respect constraints

### Example Validation Errors

```json
{
  "error": "CONSTRAINT_VIOLATION",
  "message": "Estimated EPI (0.20 J/token) exceeds power budget",
  "details": {
    "estimated_epi": 0.20,
    "power_cap_w": 150.0,
    "estimated_power_w": 165.0
  }
}
```

---

## IR Execution Model

### Runtime Interpretation

```
EA-IR (JSON)
    ↓
[Runtime Loader] → In-Memory IR
    ↓
[Scheduler] → Task Queue
    ↓
[Transform Executor] → Apply Transforms
    ↓
[Resource Manager] → Allocate GPU/Memory
    ↓
[Control Loop] → Execute with DVFS
    ↓
[Telemetry Monitor] → Collect Metrics
    ↓
[Feedback Evaluator] → Check Thresholds
    ↓ (if violated)
[Recompiler] → New IR
```

### State Machine

```
PENDING → COMPILING → SCHEDULED → RUNNING → COMPLETED
                                      ↓
                                  RECOMPILING (if feedback triggered)
                                      ↓
                                  RUNNING (with new IR)
```

---

## IR Extensions (Future)

### v0.2: Multi-GPU Support

```json
{
  "execution_plan": {
    "resources": {
      "gpu_allocation": ["gpu0", "gpu1"],
      "parallelism": {
        "type": "tensor_parallel",
        "sharding_strategy": "megatron"
      }
    }
  }
}
```

### v0.3: Conditional Execution

```json
{
  "execution_plan": {
    "conditionals": [
      {
        "condition": "EPI > 0.15",
        "action": {
          "type": "apply_transform",
          "transform_id": "aggressive_quantize"
        }
      }
    ]
  }
}
```

---

## Appendix: IR Schema (JSON Schema)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EA-IR Schema",
  "type": "object",
  "required": ["ir_version", "meta", "constraints", "execution_plan"],
  "properties": {
    "ir_version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "meta": {
      "type": "object",
      "required": ["model_id", "created_at"],
      "properties": {
        "model_id": {"type": "string"},
        "created_at": {"type": "string", "format": "date-time"}
      }
    },
    "constraints": {
      "type": "object",
      "required": ["power_cap_w", "latency_slo_ms", "quality_floor"],
      "properties": {
        "power_cap_w": {"type": "number", "minimum": 0},
        "latency_slo_ms": {"type": "number", "minimum": 0},
        "quality_floor": {"type": "number", "minimum": 0, "maximum": 1}
      }
    }
  }
}
```

---

**Document Version**: 0.1.0  
**Last Updated**: 2025-12-11  
**Status**: Stable
