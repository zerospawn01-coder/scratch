# EA-AOL v0.1 Formal Grammar Specification

**License**: CC0 1.0 Universal (Public Domain)  
**Version**: 0.1.0  
**Date**: 2025-12-11

---

## EBNF Grammar Definition

```ebnf
(* EA-AOL Language Grammar - Extended Backus-Naur Form *)

program        ::= inference_block (profile_block | policy_block | runtime_block)*

inference_block::= "inference:" NEWLINE INDENT kv_map DEDENT
profile_block  ::= "profile:" NEWLINE INDENT kv_map DEDENT
policy_block   ::= "policy:" NEWLINE INDENT kv_map DEDENT
runtime_block  ::= "runtime:" NEWLINE INDENT kv_map DEDENT

kv_map         ::= (key ":" value NEWLINE)+

key            ::= IDENTIFIER
value          ::= scalar | list | map

scalar         ::= STRING | NUMBER | BOOLEAN | UNIT_VALUE
list           ::= "[" (value ("," value)*)? "]"
map            ::= "{" (key ":" value ("," key ":" value)*)? "}"

UNIT_VALUE     ::= NUMBER UNIT
UNIT           ::= "W" | "ms" | "MHz" | "GHz" | "MB" | "GB" | "C"

IDENTIFIER     ::= [a-zA-Z_][a-zA-Z0-9_-]*
STRING         ::= '"' [^"]* '"' | "'" [^']* "'"
NUMBER         ::= [0-9]+ ("." [0-9]+)? ([eE][+-]?[0-9]+)?
BOOLEAN        ::= "true" | "false"

INDENT         ::= (* Indentation increase *)
DEDENT         ::= (* Indentation decrease *)
NEWLINE        ::= "\n" | "\r\n"
```

---

## YAML Schema Definition

### Required Fields

#### `inference` Block (Required)

| Field | Type | Unit | Required | Description |
|-------|------|------|----------|-------------|
| `model_id` | string | - | ✅ Yes | Model identifier (e.g., "llama-2-7b") |
| `power_cap` | number | W | ✅ Yes | System power limit in Watts |
| `latency_slo_ms` | number | ms | ✅ Yes | P99 latency SLO in milliseconds |
| `quality_floor` | number | [0,1] | ✅ Yes | Minimum quality ratio vs baseline |

#### `inference.orchestrator` Sub-block (Optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `layers` | list[string] | `[]` | Transformation stack (e.g., ["sparse", "moe"]) |
| `dvfs_granularity` | enum | `"batch"` | DVFS adjustment granularity: "batch", "token", "layer" |
| `cooling` | enum | `"air"` | Cooling mode: "air", "liquid_static", "liquid_dynamic", "immersed" |
| `monitoring` | list[string] | `["EPI"]` | Metrics to monitor (e.g., ["EPI", "TEMP_MAP"]) |

### Optional Blocks

#### `profile` Block

| Field | Type | Description |
|-------|------|-------------|
| `model_cost.flop_per_token` | number | FLOPs per token |
| `model_cost.mem_bw_per_token` | number/string | Memory bandwidth per token (e.g., "1400MB") |
| `model_cost.param_count` | number | Total model parameters |
| `baseline_quality` | number | Baseline quality score (default: 1.0) |
| `baseline_epi` | number | Baseline EPI in J/token |

#### `policy` Block

| Field | Type | Description |
|-------|------|-------------|
| `prefer` | list[string] | Optimization priorities (e.g., ["min_energy", "max_quality"]) |
| `hard_constraints` | list[string] | Non-negotiable constraints |
| `soft_constraints` | list[map] | Soft constraints with weights |

#### `runtime` Block

| Field | Type | Description |
|-------|------|-------------|
| `target_hardware` | string | Hardware target (e.g., "nv_gpu_single") |
| `gpu_model` | string | Specific GPU model (e.g., "A100-80GB") |
| `telemetry_endpoint` | string | Telemetry sink URI |
| `log_level` | enum | Logging level: "DEBUG", "INFO", "WARN", "ERROR" |
| `recompile_limit` | number | Max automatic recompilations per request |

---

## Complete Example

```yaml
# EA-AOL v0.1 Complete Example
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
    param_count: 13e9
  baseline_quality: 1.0
  baseline_epi: 0.18

policy:
  prefer:
    - "min_energy"
    - "max_quality"
    - "thermal_stability"
  hard_constraints:
    - "power_cap"
    - "latency_slo_ms"
    - "quality_floor"
  soft_constraints:
    - name: "temp_limit"
      value: 80C
      weight: 0.8

runtime:
  target_hardware: "nv_gpu_single"
  gpu_model: "A100-80GB"
  telemetry_endpoint: "unix:/var/run/ea_aol.sock"
  log_level: "INFO"
  recompile_limit: 3
```

---

## Validation Rules

### Type Constraints

1. **power_cap**: Must be positive number
2. **latency_slo_ms**: Must be positive number
3. **quality_floor**: Must be in range [0.0, 1.0]
4. **model_id**: Must be non-empty string

### Semantic Constraints

1. **Consistency**: If `baseline_epi` is specified in `profile`, it should be used for quality estimation
2. **Hardware Compatibility**: `target_hardware` must match available hardware
3. **Transform Compatibility**: Transforms in `orchestrator.layers` must be supported by runtime

### Unit Parsing

Units are case-sensitive and follow SI conventions:

- Power: `W` (Watts)
- Time: `ms` (milliseconds)
- Frequency: `MHz`, `GHz`
- Memory: `MB`, `GB`
- Temperature: `C` (Celsius)

---

## Grammar Extensions (Future)

### v0.2 Planned Extensions

```ebnf
(* Multi-GPU support *)
inference_block ::= "inference:" NEWLINE INDENT 
                    (kv_map | multi_gpu_block) 
                    DEDENT

multi_gpu_block ::= "gpus:" NEWLINE INDENT 
                    gpu_spec+ 
                    DEDENT

gpu_spec        ::= "- id:" STRING NEWLINE 
                    "  power_cap:" UNIT_VALUE NEWLINE
```

### v0.3 Planned Extensions

```ebnf
(* Conditional execution *)
conditional     ::= "if:" condition NEWLINE 
                    INDENT action_block DEDENT

condition       ::= metric COMPARATOR value
COMPARATOR      ::= ">" | "<" | "==" | ">=" | "<="
```

---

## Appendix: Railroad Diagrams

### Program Structure

```
program
├── inference_block (required)
└── (profile_block | policy_block | runtime_block)* (optional)
```

### Value Types

```
value
├── scalar
│   ├── STRING
│   ├── NUMBER
│   ├── BOOLEAN
│   └── UNIT_VALUE
├── list
│   └── "[" value ("," value)* "]"
└── map
    └── "{" key ":" value ("," key ":" value)* "}"
```

---

**Document Version**: 0.1.0  
**Last Updated**: 2025-12-11  
**Status**: Stable
