# EA-AOL Metrics & EPI Specification

**Version**: 0.1.0  
**Date**: 2025-12-11  
**License**: CC0 1.0 Universal (Public Domain)

---

## Overview

This document defines the **Energy Performance Indicator (EPI)** and related metrics used in EA-AOL for measuring and optimizing AI inference energy efficiency.

---

## 1. EPI Definition

### 1.1 Primary Metric

**EPI (Energy Per Inference)**: Joules consumed per generated token

```
EPI = Energy (J) / Tokens Generated
```

**Unit**: J/token (Joules per token)

### 1.2 Why EPI?

- **Normalized**: Independent of batch size and throughput
- **Actionable**: Directly relates to energy cost
- **Comparable**: Enables cross-model, cross-hardware comparison
- **Optimizable**: Clear target for energy reduction

---

## 2. EPI Calculation Methods

### 2.1 Estimated EPI (Model-Based)

Used during compilation and planning:

```
EPI_est = (FLOPs/token × α) + (Bytes/token × β) + E_overhead
```

Where:
- `FLOPs/token`: Computational operations per token
- `Bytes/token`: Memory bandwidth per token
- `α`: Energy coefficient for compute (J/FLOP)
- `β`: Energy coefficient for memory (J/Byte)
- `E_overhead`: Fixed overhead energy (J)

#### Example Values (NVIDIA A100)

```c
ea_cost_model_t model = {
    .flops_per_token = 1.4e10,     // 14 GFLOPs
    .mem_bw_per_token = 800e6,     // 800 MB
    .alpha = 1.0e-12,              // 1 pJ/FLOP
    .beta = 5.0e-9,                // 5 nJ/Byte
    .overhead_j = 0.001            // 1 mJ
};

// EPI_est = (1.4e10 * 1e-12) + (800e6 * 5e-9) + 0.001
//         = 0.014 + 4.0 + 0.001
//         = 4.015 J/token
```

### 2.2 Real EPI (Measurement-Based)

Used during runtime execution:

```
EPI_real = P_gpu (W) / Throughput (tokens/s)
```

Where:
- `P_gpu`: GPU power consumption (Watts)
- `Throughput`: Token generation rate (tokens/second)

#### Measurement Example

```python
# Collect metrics
power_w = 185.2          # From NVML
throughput_tps = 45.0    # From inference loop

# Calculate EPI
epi_real = power_w / throughput_tps
# epi_real = 185.2 / 45.0 = 4.11 J/token
```

---

## 3. Related Metrics

### 3.1 Power Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| `P_gpu` | W | GPU power consumption |
| `P_system` | W | Total system power |
| `P_avg` | W | Average power over window |
| `P_peak` | W | Peak power observed |

### 3.2 Performance Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| `Throughput` | tokens/s | Token generation rate |
| `Latency_P50` | ms | Median latency |
| `Latency_P99` | ms | 99th percentile latency |
| `TTFT` | ms | Time to first token |

### 3.3 Quality Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| `Quality_Score` | [0,1] | Task-specific quality |
| `Quality_Ratio` | [0,1] | Quality vs baseline |
| `Perplexity` | - | Language model perplexity |
| `BLEU` | [0,100] | Translation quality |

### 3.4 Efficiency Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| `EPI` | J/token | Energy per token (primary) |
| `J_per_request` | J | Energy per request |
| `Tokens_per_J` | tokens/J | Energy efficiency |
| `Performance_per_W` | tokens/s/W | Power efficiency |

---

## 4. Telemetry JSON Format

### 4.1 Real-Time Telemetry

```json
{
  "timestamp": 1700001234,
  "metrics": {
    "power_w": 185.2,
    "throughput_tps": 45.0,
    "epi_j_per_token": 4.11,
    "latency_p99_ms": 48.2,
    "quality_score": 0.92
  },
  "status": {
    "violation": "power_cap",
    "current_action": "reduce_top_k",
    "active_k": 3,
    "gpu_freq_mhz": 1200
  },
  "cumulative": {
    "total_tokens": 12450,
    "total_energy_j": 51189.5,
    "avg_epi": 4.11
  }
}
```

### 4.2 Field Definitions

#### `metrics` Object

| Field | Type | Description |
|-------|------|-------------|
| `power_w` | number | Current GPU power (W) |
| `throughput_tps` | number | Tokens per second |
| `epi_j_per_token` | number | Current EPI (J/token) |
| `latency_p99_ms` | number | P99 latency (ms) |
| `quality_score` | number | Quality metric [0,1] |

#### `status` Object

| Field | Type | Description |
|-------|------|-------------|
| `violation` | string | Constraint being violated (or null) |
| `current_action` | string | Active control action |
| `active_k` | number | Current MoE Top-K value |
| `gpu_freq_mhz` | number | Current GPU frequency |

#### `cumulative` Object

| Field | Type | Description |
|-------|------|-------------|
| `total_tokens` | number | Total tokens generated |
| `total_energy_j` | number | Total energy consumed (J) |
| `avg_epi` | number | Average EPI over session |

---

## 5. EPI Visualization

### 5.1 Real-Time Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│ EA-AOL Energy Monitor                                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Power: ████████████████░░░░ 185.2 W / 180.0 W (103%)     │
│  EPI:   ████████████░░░░░░░░ 4.11 J/tok (Target: 4.0)     │
│  Latency: ██████████████░░░░ 48.2 ms / 50.0 ms (96%)      │
│  Quality: ████████████████░░ 0.92 / 0.90 (102%)           │
│                                                             │
│  Status: ⚠️  POWER CAP EXCEEDED                            │
│  Action: 🔧 Reducing MoE Top-K (k=4 → k=3)                │
│                                                             │
│  EPI History (last 60s):                                   │
│  4.5 │     ╭─╮                                             │
│  4.0 │  ╭──╯ ╰──╮                                          │
│  3.5 │──╯       ╰────────                                  │
│  3.0 │                                                     │
│      └─────────────────────────────────────────────────    │
│       0s    20s    40s    60s                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Python Visualization Code

```python
import matplotlib.pyplot as plt
import matplotlib.animation as animation

class EPIMonitor:
    def __init__(self):
        self.fig, (self.ax1, self.ax2) = plt.subplots(2, 1, figsize=(10, 8))
        self.epi_history = []
        self.power_history = []
        self.time_history = []
        
    def update(self, frame):
        # Fetch telemetry
        telemetry = fetch_telemetry()
        
        self.time_history.append(telemetry['timestamp'])
        self.epi_history.append(telemetry['metrics']['epi_j_per_token'])
        self.power_history.append(telemetry['metrics']['power_w'])
        
        # Plot EPI
        self.ax1.clear()
        self.ax1.plot(self.time_history, self.epi_history, 'b-', label='EPI')
        self.ax1.axhline(y=4.0, color='r', linestyle='--', label='Target')
        self.ax1.set_ylabel('EPI (J/token)')
        self.ax1.legend()
        self.ax1.grid(True)
        
        # Plot Power
        self.ax2.clear()
        self.ax2.plot(self.time_history, self.power_history, 'g-', label='Power')
        self.ax2.axhline(y=180.0, color='r', linestyle='--', label='Cap')
        self.ax2.set_xlabel('Time (s)')
        self.ax2.set_ylabel('Power (W)')
        self.ax2.legend()
        self.ax2.grid(True)
    
    def run(self):
        ani = animation.FuncAnimation(
            self.fig, self.update, interval=500, blit=False
        )
        plt.show()

# Usage
monitor = EPIMonitor()
monitor.run()
```

---

## 6. EPI Optimization Strategies

### 6.1 Model-Level Optimizations

| Strategy | EPI Impact | Quality Impact |
|----------|-----------|----------------|
| **Sparsification** | -20% to -35% | -2% to -5% |
| **Quantization (INT8)** | -15% to -25% | -1% to -3% |
| **MoE Top-K Reduction** | -10% to -20% | -3% to -8% |
| **Layer Skipping** | -15% to -30% | -5% to -10% |

### 6.2 Hardware-Level Optimizations

| Strategy | EPI Impact | Latency Impact |
|----------|-----------|----------------|
| **DVFS (Freq Reduction)** | -10% to -20% | +5% to +15% |
| **Batch Size Tuning** | -5% to -15% | Variable |
| **Memory Optimization** | -5% to -10% | -2% to +5% |

### 6.3 Combined Optimization

```
Baseline EPI: 4.5 J/token

Apply Sparsification (50%):  4.5 → 3.15 J/token (-30%)
Apply DVFS (1500→1200 MHz):  3.15 → 2.65 J/token (-16%)
Apply MoE k=4→k=3:           2.65 → 2.25 J/token (-15%)

Final EPI: 2.25 J/token (50% reduction)
Quality: 0.91 (vs 1.0 baseline, -9%)
```

---

## 7. Benchmarking Protocol

### 7.1 Standard Test

```yaml
# benchmark_config.yaml
inference:
  model_id: "llama-2-13b"
  power_cap: 150W
  latency_slo_ms: 50
  quality_floor: 0.90

benchmark:
  duration_s: 300
  warmup_s: 30
  input_length: 512
  output_length: 128
  num_samples: 100
```

### 7.2 Metrics to Report

1. **Average EPI** (J/token)
2. **P50/P99 Latency** (ms)
3. **Quality Score** (task-specific)
4. **Power Cap Violations** (%)
5. **SLO Compliance** (%)

### 7.3 Comparison Format

```
Model: LLaMA-2-13B
Hardware: NVIDIA A100-80GB

Configuration    | EPI (J/tok) | Latency P99 | Quality | Violations
-----------------|-------------|-------------|---------|------------
Baseline         | 4.50        | 45.2 ms     | 1.00    | 0%
EA-AOL (k=4)     | 3.15        | 48.1 ms     | 0.96    | 0%
EA-AOL (k=3)     | 2.65        | 51.2 ms     | 0.92    | 2%
EA-AOL (k=2)     | 2.25        | 55.8 ms     | 0.87    | 8%
```

---

## 8. API Integration

### 8.1 C API

```c
#include "ea_aol.h"

// Get current EPI
double epi = ea_aol_get_epi(ctx);

// Get detailed metrics
ea_metrics_t metrics;
ea_aol_get_metrics(ctx, &metrics);

printf("EPI: %.3f J/token\n", metrics.epi_j_per_token);
printf("Power: %.1f W\n", metrics.power_w);
printf("Throughput: %.1f tokens/s\n", metrics.throughput_tps);
```

### 8.2 Python API

```python
from ea_aol import Runtime

runtime = Runtime("config.yaml")

# Get metrics
metrics = runtime.get_metrics()
print(f"EPI: {metrics.epi:.3f} J/token")
print(f"Power: {metrics.power:.1f} W")

# Stream telemetry
for telemetry in runtime.stream_telemetry():
    print(f"EPI: {telemetry.epi:.3f} J/token")
```

---

## Appendix: Conversion Factors

### Energy Units

- 1 J = 1000 mJ = 1,000,000 μJ
- 1 Wh = 3600 J
- 1 kWh = 3,600,000 J

### Power Units

- 1 W = 1 J/s
- 1 kW = 1000 W

### Example Conversions

```
EPI = 4.0 J/token

For 1M tokens:
  Energy = 4.0 J/token × 1,000,000 tokens = 4,000,000 J = 4 MJ
  = 1.11 kWh

At $0.12/kWh:
  Cost = 1.11 kWh × $0.12 = $0.133
```

---

**Document Version**: 0.1.0  
**Last Updated**: 2025-12-11  
**Status**: Stable
