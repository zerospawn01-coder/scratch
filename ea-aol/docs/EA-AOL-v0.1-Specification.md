# EA-AOL v0.1 Language Specification

**Energy-Aware AI Orchestration Language**

Version: 0.1.0  
Date: 2025-12-11  
License: CC0 1.0 Universal (Public Domain)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Design Principles](#design-principles)
3. [Language Syntax](#language-syntax)
4. [Formal Grammar (BNF)](#formal-grammar-bnf)
5. [Required and Optional Keys](#required-and-optional-keys)
6. [Intermediate Representation (IR)](#intermediate-representation-ir)
7. [Runtime API Specification](#runtime-api-specification)
8. [Energy Performance Indicator (EPI) Metrics](#energy-performance-indicator-epi-metrics)
9. [Extension Points](#extension-points)
10. [License Strategy](#license-strategy)

---

## 1. Introduction

EA-AOL (Energy-Aware AI Orchestration Language) is a **declarative domain-specific language** designed to enable users to specify inference requirements through Service Level Objectives (SLOs) while allowing the compiler and runtime to perform joint optimization across:

- **Model structure** (sparsification, MoE routing, layer pruning)
- **Physical control** (DVFS, PSU management, cooling)
- **Resource placement** (GPU, PCIe, host memory)
- **Closed-loop feedback** (EPI monitoring and adaptive re-planning)

### Goals

1. **Declarative Requirements**: Users declare `power_cap`, `latency_slo`, and `quality_floor` without specifying implementation details
2. **Variable Materialization**: Runtime generates execution plans by combining model transformations, physical controls, and placement strategies
3. **Observation and Feedback**: Continuous monitoring of EPI and other metrics enables dynamic IR updates

### Non-Goals

- EA-AOL is **not** a general-purpose programming language
- EA-AOL does **not** replace PyTorch/TensorFlow; it orchestrates them
- EA-AOL does **not** mandate specific hardware; it provides abstraction layers

---

## 2. Design Principles

### 2.1 Separation of Concerns

- **What** (user intent) vs **How** (implementation strategy)
- Users specify constraints; runtime determines optimal execution

### 2.2 Composability

- Transformation layers (sparse, MoE, quantization) are composable
- Energy models are pluggable
- Telemetry adapters are extensible

### 2.3 Vendor Neutrality

- Language specification is open (CC0)
- Reference implementation is permissive (BSD-2-Clause)
- Commercial and open-source implementations can coexist

### 2.4 Measurability

- All optimizations must be measurable via EPI and related metrics
- Feedback loops ensure SLO compliance

---

## 3. Language Syntax

EA-AOL uses YAML-like syntax for human readability and machine parseability.

### 3.1 Basic Structure

```yaml
inference:
  model_id: "llama-13b"
  power_cap: 150W
  latency_slo_ms: 20
  quality_floor: 0.95
  orchestrator:
    layers: ["sparse", "moe", "cache_compress"]
    dvfs_granularity: "token"
    cooling: "liquid_dynamic"
    monitoring: ["EPI", "J_PER_TOKEN", "TEMP_MAP"]

profile:
  model_cost:
    flop_per_token: 1.2e9
    mem_bw_per_token: 1200MB
  baseline_quality: 1.0

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
```

### 3.2 Comments

```yaml
# This is a comment
inference:
  model_id: "gpt-j-6b"  # Inline comment
```

### 3.3 Units

- Power: `W` (watts)
- Latency: `ms` (milliseconds)
- Memory: `MB`, `GB`
- Quality: dimensionless float `[0.0, 1.0]`

---

## 4. Formal Grammar (BNF)

```bnf
<program>      ::= <inference_stmt> ( <profile_stmt> | <policy_stmt> | <runtime_stmt> )*

<inference_stmt> ::= "inference" ":" <block>
<profile_stmt>   ::= "profile" ":" <block>
<policy_stmt>    ::= "policy" ":" <block>
<runtime_stmt>   ::= "runtime" ":" <block>

<block>        ::= INDENT <kvpair>* DEDENT
<kvpair>       ::= <key> ":" <value>

<key>          ::= IDENTIFIER
<value>        ::= <scalar> | <list> | <map>

<scalar>       ::= STRING | NUMBER | BOOLEAN | UNIT_VALUE
<list>         ::= "[" ( <value> ( "," <value> )* )? "]"
<map>          ::= "{" ( <kvpair> ( "," <kvpair> )* )? "}"

<unit_value>   ::= NUMBER UNIT
<unit>         ::= "W" | "ms" | "MB" | "GB" | "MHz" | "GHz"

IDENTIFIER     ::= /[a-zA-Z_][a-zA-Z0-9_-]*/
STRING         ::= /"[^"]*"/ | /'[^']*'/
NUMBER         ::= /[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?/
BOOLEAN        ::= "true" | "false"
```

**Note**: The reference implementation uses a YAML-compliant parser, so full YAML features (anchors, aliases, multi-line strings) are supported.

---

## 5. Required and Optional Keys

### 5.1 Required Keys (`inference` block)

| Key | Type | Description | Example |
|-----|------|-------------|---------|
| `model_id` | string | Model identifier | `"llama-13b"` |
| `power_cap` | number (W) | Total node power limit | `150W` |
| `latency_slo_ms` | number (ms) | P99 latency SLO | `20` |
| `quality_floor` | float [0,1] | Minimum quality ratio vs baseline | `0.95` |

### 5.2 Recommended Keys (`orchestrator` sub-block)

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `layers` | list[string] | Transformation stack | `[]` |
| `dvfs_granularity` | enum | `batch`, `token`, `layer` | `batch` |
| `cooling` | enum | `air`, `liquid_static`, `liquid_dynamic`, `immersed` | `air` |
| `monitoring` | list[string] | Metrics to track | `["EPI"]` |

### 5.3 Optional Keys

- `profile.model_cost`: Model metadata (FLOPs, memory bandwidth)
- `policy.prefer`: Optimization priorities (list)
- `policy.hard_constraints`: Non-negotiable constraints
- `runtime.target_hardware`: Hardware target identifier
- `runtime.telemetry_endpoint`: Telemetry sink URI

---

## 6. Intermediate Representation (IR)

The compiler transforms EA-AOL declarations into an executable IR.

### 6.1 IR Schema

```yaml
EA_IR:
  meta:
    model_id: string
    created_at: timestamp
    compiler_version: string
  
  constraints:
    power_cap_w: float
    latency_slo_ms: float
    quality_floor: float
  
  cost_models:
    flop_per_token: float
    mem_bw_per_token: float
    energy_model: |
      function(params) -> estimated_W
      # Pluggable energy estimation function
  
  transforms:
    - id: "sparse_layer_prune"
      params:
        layer_indices: [12, 18, 24]
        sparsity_targets: [0.5, 0.6, 0.7]
    
    - id: "moe_routing_power_aware"
      params:
        budget_w: 120
        k_max: 4
    
    - id: "dvfs_plan"
      params:
        token_schedule:
          - {t0: 0, freq: 1200MHz}
          - {t0: 100, freq: 1500MHz}
  
  placement:
    - host: "gpu0"
      partitions:
        - layers: [0, 15]
          memory: "gpu_vram"
        - layers: [16, 31]
          memory: "host_pinned"
  
  control_plan:
    - time_window_ms: 10
      actions:
        - type: "set_gpu_freq"
          target: "gpu0"
          freq: 1200MHz
        
        - type: "set_psu_mode"
          target: "psu0"
          mode: "burst_absorb"
  
  feedback_hooks:
    - metric: "EPI"
      condition: "deviation > 5%"
      action: "recompile"
    
    - metric: "TEMP_MAP.gpu0_die"
      condition: "> 85C"
      action: "throttle"
```

### 6.2 IR Execution Flow

1. **Parse** EA-AOL YAML → AST
2. **Validate** constraints and keys
3. **Cost Estimation** using `cost_models`
4. **Transform Planning** (sparse, MoE, DVFS)
5. **Placement Optimization** (GPU/CPU/memory)
6. **Control Plan Generation** (physical actions)
7. **Feedback Hook Registration** (monitoring thresholds)

---

## 7. Runtime API Specification

### 7.1 C ABI

See `spec/ea_aol.h` for complete header.

```c
typedef struct ea_aol_ctx_t ea_aol_ctx_t;

// Initialize runtime
ea_aol_ctx_t* ea_aol_init(const char *config_path);

// Submit inference request
int ea_aol_schedule(ea_aol_ctx_t *ctx, inference_request_t *req);

// Query status
int ea_aol_status(ea_aol_ctx_t *ctx, const char *request_id, 
                  char *out_json, size_t out_size);

// Get EPI metric
int ea_aol_get_epi(ea_aol_ctx_t *ctx, const char *request_id, 
                   double *out_epi_j_per_token);

// Cancel request
int ea_aol_cancel(ea_aol_ctx_t *ctx, const char *request_id);

// Shutdown
void ea_aol_shutdown(ea_aol_ctx_t *ctx);
```

### 7.2 gRPC Protocol

See `spec/orchestrator.proto` for complete definition.

```protobuf
service Orchestrator {
  rpc SubmitInference(InferenceRequest) returns (SubmitReply);
  rpc GetStatus(StatusRequest) returns (StatusReply);
  rpc StreamTelemetry(StreamRequest) returns (stream Telemetry);
  rpc CancelInference(CancelRequest) returns (CancelReply);
}
```

### 7.3 Side Channels

- **sysfs**: `/sys/ea_aol/control` for runtime mode switches
- **Unix socket**: `/var/run/ea_aol.sock` for local telemetry
- **HTTP**: Optional REST API for web dashboards

---

## 8. Energy Performance Indicator (EPI) Metrics

### 8.1 Primary Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| `EPI_J_PER_TOKEN` | J/token | Energy per generated token |
| `J_PER_REQUEST` | J | Energy per inference request |
| `W_AVG` | W | Average power during execution |
| `P99_LATENCY_MS` | ms | 99th percentile latency |
| `QUALITY_SCORE` | [0,1] | Task-specific quality metric |

### 8.2 Telemetry Format (JSON)

```json
{
  "request_id": "r-001",
  "ts": 1699999999,
  "epi_j_per_token": 0.12,
  "power_w": 132.5,
  "latency_ms_p99": 18.2,
  "quality_score": 0.96,
  "temp_map": {
    "gpu0_die": 72.1,
    "inlet": 25.4
  }
}
```

### 8.3 Evaluation Rules

- Runtime evaluates EPI every **5 seconds** (configurable)
- If `quality_floor` violated → trigger recompile
- If `power_cap` exceeded → apply emergency throttle
- Maximum **3 automatic recompiles** per request (prevent oscillation)

---

## 9. Extension Points

EA-AOL is designed for extensibility:

### 9.1 Energy Models

Replace `energy_model` function in IR:

```python
def custom_energy_model(freq_mhz, bw_gb_s, flops):
    return alpha * freq_mhz + beta * bw_gb_s + gamma * flops
```

### 9.2 Transformation Plugins

Add new transformation layers:

```yaml
orchestrator:
  layers: ["sparse", "moe", "my_custom_transform"]
```

Plugin interface:

```python
class TransformPlugin:
    def apply(self, model, params):
        # Return transformed model
        pass
```

### 9.3 PSU Drivers

Abstract PSU control:

```c
typedef struct psu_driver_t {
    int (*set_mode)(const char *mode);
    int (*get_power)(double *out_watts);
} psu_driver_t;
```

### 9.4 Telemetry Adapters

Support multiple backends:

- NVML (NVIDIA GPUs)
- sysfs (Linux kernel)
- IPMI (server BMC)
- Custom hardware sensors

---

## 10. License Strategy

### 10.1 Language Specification

**License**: CC0 1.0 Universal (Public Domain)

- Anyone can implement EA-AOL without restrictions
- No patent claims on the language itself
- Encourages broad adoption and standardization

### 10.2 Reference Implementation

**License**: BSD-2-Clause

- Permissive for commercial use
- Minimal attribution requirement
- Allows proprietary derivatives

### 10.3 Rationale

- **Open specification** prevents vendor lock-in
- **Permissive implementation** encourages ecosystem growth
- Follows successful models (HTTP, SQL, LLVM)

---

## Appendix A: Complete Example

```yaml
# EA-AOL v0.1 Complete Example
inference:
  model_id: "llama-2-13b-chat"
  power_cap: 150W
  latency_slo_ms: 25
  quality_floor: 0.93
  
  orchestrator:
    layers:
      - "sparse_attention"
      - "moe_ffn"
      - "kv_cache_compress"
    dvfs_granularity: "token"
    cooling: "liquid_dynamic"
    monitoring:
      - "EPI"
      - "J_PER_TOKEN"
      - "TEMP_MAP"
      - "POWER_WAVEFORM"

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

## Appendix B: Glossary

- **DVFS**: Dynamic Voltage and Frequency Scaling
- **EPI**: Energy Performance Indicator (J/token)
- **IR**: Intermediate Representation
- **MoE**: Mixture of Experts
- **PSU**: Power Supply Unit
- **SLO**: Service Level Objective

---

**Document Version**: 0.1.0  
**Last Updated**: 2025-12-11  
**Maintainer**: EA-AOL Community  
**Contact**: (To be established)
