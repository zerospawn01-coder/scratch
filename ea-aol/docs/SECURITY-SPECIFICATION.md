# EA-AOL Security & Safety Specification v0.1

**Date**: 2025-12-11  
**Status**: CRITICAL - Must be implemented before production use  
**License**: CC0 1.0 Universal (Public Domain)

---

## ⚠️ Security Warning

EA-AOL controls **physical hardware** (GPU voltage, frequency, cooling). Unlike web applications, bugs can cause:

- 🔥 **Hardware damage** (GPU burnout, VRM failure)
- 💥 **System crashes** (kernel panic, BSOD)
- 🔓 **Security breaches** (privilege escalation, data leakage)

**This document defines mandatory security measures for v0.1 and beyond.**

---

## 🛡️ 1. Input & Compiler Layer Vulnerabilities

### Threat Model

#### 1.1 YAML Bomb Attack

**Attack**: Recursive YAML definitions cause exponential memory expansion

```yaml
# Malicious YAML
a: &anchor
  b: *anchor
  c: *anchor
```

**Impact**: Compiler memory exhaustion, DoS

**Mitigation**: Use `yaml.safe_load()` exclusively

```python
# ❌ DANGEROUS
yaml.load(f, Loader=yaml.Loader)

# ✅ SAFE
yaml.safe_load(f)
```

**Implementation**: Already enforced in `ir_compiler.py`

#### 1.2 JSON Buffer Overflow

**Attack**: Attacker sends 1MB string to `char model_id[64]`

```json
{
  "meta": {
    "model_id": "AAAA...AAAA"  // 1,000,000 'A's
  }
}
```

**Impact**: Memory corruption, arbitrary code execution

**Mitigation**: Strict boundary checking with rejection (not truncation)

```cpp
#define MAX_ID_LEN 63

void safe_copy_string(char* dest, const char* src, size_t max_len) {
    size_t src_len = strnlen(src, max_len + 1);
    
    if (src_len > max_len) {
        // ❌ DO NOT truncate silently - reject entire input
        throw std::runtime_error(
            "Security: Input string exceeds buffer limit"
        );
    }
    
    strncpy(dest, src, max_len);
    dest[max_len] = '\0';
}
```

**Rationale**: Silent truncation can cause ID collisions and logic errors

#### 1.3 Numeric Overflow

**Attack**: Extreme values cause integer overflow

```yaml
inference:
  power_cap: 999999999999999999999  # Overflows double
  latency_slo_ms: -1                # Negative latency
```

**Mitigation**: Range validation

```python
def _validate_constraints(self, constraints):
    """Validate constraint ranges"""
    if not (0 < constraints['power_cap_w'] <= 1000):
        raise CompilerError("power_cap_w must be in range (0, 1000]")
    
    if not (0 < constraints['latency_slo_ms'] <= 10000):
        raise CompilerError("latency_slo_ms must be in range (0, 10000]")
    
    if not (0 <= constraints['quality_floor'] <= 1.0):
        raise CompilerError("quality_floor must be in range [0, 1]")
```

### Implementation Checklist (Day 2-3)

- [x] ✅ Use `yaml.safe_load()` in compiler
- [ ] ⬜ Add range validation to compiler
- [ ] ⬜ Implement `safe_copy_string()` in C++ loader
- [ ] ⬜ Add numeric overflow checks in C++ loader

---

## ⚡ 2. Physical Hardware Control Risks

### Threat Model

#### 2.1 Privilege Escalation

**Problem**: GPU control requires root, but running entire runtime as root is dangerous

**Attack Scenario**:
1. Attacker exploits buffer overflow in runtime
2. Runtime is running as root
3. Attacker gains root shell
4. System compromised

**Solution**: Privilege Separation

```
┌─────────────────────────────────────────┐
│  User Space (non-root)                  │
│  ├── EA-AOL Runtime                     │
│  ├── PyTorch Application                │
│  └── Telemetry Collector                │
└────────────┬────────────────────────────┘
             │ IPC (Unix socket / pipe)
             ▼
┌─────────────────────────────────────────┐
│  Root Space (minimal, audited)          │
│  └── Hardware Control Daemon            │
│      - Input sanitization               │
│      - Command whitelist                │
│      - Rate limiting                    │
└─────────────────────────────────────────┘
```

#### 2.2 Command Injection

**Attack**: Runtime passes unsanitized input to shell

```cpp
// ❌ DANGEROUS
char cmd[256];
sprintf(cmd, "nvidia-smi -lgc %s", user_input);
system(cmd);

// If user_input = "1500; rm -rf /"
// Executes: nvidia-smi -lgc 1500; rm -rf /
```

**Mitigation**: Sanitized helper script

```bash
#!/bin/bash
# /usr/local/bin/ea_gpu_control.sh
# Owner: root, Mode: 0700

FREQ=$1

# ✅ Strict input validation
if [[ ! "$FREQ" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid frequency (must be numeric)" >&2
    exit 1
fi

# ✅ Range check
if [ "$FREQ" -lt 200 ] || [ "$FREQ" -gt 2000 ]; then
    echo "Error: Frequency out of safe range [200, 2000]" >&2
    exit 1
fi

# ✅ Execute only whitelisted command
nvidia-smi -lgc "$FREQ"
```

**Runtime calls**:

```cpp
// ✅ SAFE
char cmd[256];
snprintf(cmd, sizeof(cmd), "/usr/local/bin/ea_gpu_control.sh %d", freq_mhz);
int ret = system(cmd);
if (ret != 0) {
    // Handle error
}
```

#### 2.3 Hardware Safety Limits

**Problem**: Software bug sends extreme values to hardware

**Example**:
```cpp
// Bug: Typo causes 15000 MHz instead of 1500 MHz
int freq = 1500 * 10;  // Oops!
set_gpu_freq(freq);    // GPU overheats and dies
```

**Mitigation**: Hardware-aware clamping

```cpp
// Hardware limits for NVIDIA A100
#define GPU_FREQ_MIN_MHZ 200
#define GPU_FREQ_MAX_MHZ 2000
#define GPU_POWER_MIN_W  50
#define GPU_POWER_MAX_W  400

int clamp_freq(int freq_mhz) {
    if (freq_mhz < GPU_FREQ_MIN_MHZ) return GPU_FREQ_MIN_MHZ;
    if (freq_mhz > GPU_FREQ_MAX_MHZ) return GPU_FREQ_MAX_MHZ;
    return freq_mhz;
}

// Usage
int safe_freq = clamp_freq(requested_freq);
set_gpu_freq(safe_freq);
```

### Implementation Checklist (Day 3)

- [ ] ⬜ Create sanitized `ea_gpu_control.sh` script
- [ ] ⬜ Implement `clamp_freq()` and `clamp_power()` functions
- [ ] ⬜ Add hardware limits to `ea_ir.h`
- [ ] ⬜ Document privilege separation architecture

---

## 📉 3. Control Loop Oscillation

### Threat Model

#### 3.1 Feedback Loop Instability

**Problem**: Control actions trigger immediately, causing oscillation

**Scenario**:
```
t=0s:   Power = 195W > 180W cap
        → Reduce k (4 → 3)
        
t=0.1s: Power = 160W < 180W cap
        → Increase k (3 → 4)
        
t=0.2s: Power = 195W > 180W cap
        → Reduce k (4 → 3)
        
... oscillates at 5 Hz
```

**Impact**:
- VRM (voltage regulator) stress
- Reduced hardware lifespan
- Unstable inference quality

**Mitigation 1**: Cooldown Period

```cpp
typedef struct {
    char metric_name[32];
    char op[4];
    double threshold;
    ea_action_type_t action;
    double action_param;
    double min_value;
    double max_value;
    
    // ✅ NEW: Cooldown
    uint64_t cooldown_ms;        // Minimum time between actions
    uint64_t last_triggered_ms;  // Timestamp of last trigger
} ea_rule_t;
```

**Runtime logic**:

```cpp
bool can_trigger_rule(const ea_rule_t* rule, uint64_t current_time_ms) {
    uint64_t elapsed = current_time_ms - rule->last_triggered_ms;
    return elapsed >= rule->cooldown_ms;
}
```

**Mitigation 2**: Hysteresis

```cpp
typedef struct {
    double threshold_high;  // Trigger when exceeding this
    double threshold_low;   // Reset when below this
    bool triggered;         // Current state
} ea_hysteresis_t;
```

**Example**:
```
Power cap: 180W
Hysteresis: ±10W

Trigger: Power > 190W  (threshold_high)
Reset:   Power < 170W  (threshold_low)

This prevents oscillation in the 170-190W range
```

#### 3.2 Derivative Kick

**Problem**: Sudden changes cause overshoot

**Mitigation**: Rate limiting

```cpp
#define MAX_FREQ_CHANGE_PER_SECOND 200  // MHz/s

int apply_rate_limit(int current_freq, int target_freq, double dt_sec) {
    int max_change = (int)(MAX_FREQ_CHANGE_PER_SECOND * dt_sec);
    int delta = target_freq - current_freq;
    
    if (abs(delta) > max_change) {
        delta = (delta > 0) ? max_change : -max_change;
    }
    
    return current_freq + delta;
}
```

### Implementation Checklist (Day 3)

- [ ] ⬜ Add `cooldown_ms` to `ea_rule_t`
- [ ] ⬜ Implement cooldown logic in runtime
- [ ] ⬜ Add default cooldown (2000ms) in compiler
- [ ] ⬜ Implement rate limiting for frequency changes

---

## 🕵️ 4. Telemetry Side-Channel Attacks

### Threat Model

#### 4.1 Power Analysis Attack

**Problem**: Power consumption patterns reveal model structure and input data

**Attack**:
1. Attacker subscribes to `StreamTelemetry` gRPC endpoint
2. Observes fine-grained power traces (500ms intervals)
3. Correlates power spikes with token generation
4. Infers prompt content from power patterns

**Example**:
```
Power trace:
  150W → 180W → 195W → 170W → 150W
  
Inference:
  - Spike at 180W: Processing complex token (e.g., "quantum")
  - Spike at 195W: MoE routing to multiple experts
  - Drop to 150W: Simple token (e.g., "the")
```

**Mitigation 1**: Access Control

```protobuf
service Orchestrator {
  // ⚠️ SENSITIVE: Exposes power patterns
  rpc StreamTelemetry (StreamReq) returns (stream Telemetry) {
    option (google.api.http) = {
      get: "/v1/telemetry/stream"
    };
    // ✅ REQUIRED: mTLS authentication
    // ✅ REQUIRED: Localhost-only binding in production
  }
}
```

**Configuration**:

```yaml
runtime:
  telemetry:
    bind_address: "127.0.0.1:50051"  # ✅ Localhost only
    require_mtls: true                # ✅ Mutual TLS
    allowed_clients:                  # ✅ Whitelist
      - "CN=monitoring.internal"
```

**Mitigation 2**: Aggregation

```cpp
// Instead of raw power samples
struct RawTelemetry {
    double power_w;           // ❌ Reveals patterns
    uint64_t timestamp_ms;
};

// Use aggregated metrics
struct AggregatedTelemetry {
    double avg_power_w;       // ✅ Average over 5s window
    double max_power_w;       // ✅ Peak in window
    double epi_j_per_token;   // ✅ Normalized metric
    uint64_t window_start_ms;
    uint64_t window_end_ms;
};
```

#### 4.2 Timing Side-Channel

**Problem**: Latency variations reveal model decisions

**Mitigation**: Constant-time operations (where feasible)

```cpp
// ❌ Variable-time (leaks information)
if (quality_score < threshold) {
    apply_degradation();  // Takes 10ms
}
// Else: no-op (0ms)

// ✅ Constant-time
bool should_degrade = (quality_score < threshold);
if (should_degrade) {
    apply_degradation();
} else {
    dummy_operation();  // Same duration as apply_degradation()
}
```

### Implementation Checklist (Day 3)

- [ ] ⬜ Add access control to gRPC server
- [ ] ⬜ Implement telemetry aggregation
- [ ] ⬜ Document security best practices
- [ ] ⬜ Add localhost-only binding option

---

## 🔒 Comprehensive Security Checklist

### Compiler (Python)

- [x] ✅ Use `yaml.safe_load()`
- [ ] ⬜ Add numeric range validation
- [ ] ⬜ Validate string lengths before output
- [ ] ⬜ Add schema validation
- [ ] ⬜ Implement input sanitization

### Runtime (C++)

- [ ] ⬜ Implement `safe_copy_string()`
- [ ] ⬜ Add hardware safety limits
- [ ] ⬜ Implement cooldown logic
- [ ] ⬜ Add rate limiting
- [ ] ⬜ Implement privilege separation
- [ ] ⬜ Add telemetry access control

### Deployment

- [ ] ⬜ Create sanitized control scripts
- [ ] ⬜ Configure sudo permissions (minimal)
- [ ] ⬜ Set up mTLS for gRPC
- [ ] ⬜ Enable audit logging
- [ ] ⬜ Document security architecture

---

## 📋 Updated `ea_ir.h` with Security Features

```c
/* Security-enhanced ea_ir.h */

#ifndef EA_IR_H
#define EA_IR_H

#include <stdint.h>

// ✅ Hardware safety limits
#define GPU_FREQ_MIN_MHZ 200
#define GPU_FREQ_MAX_MHZ 2000
#define GPU_POWER_MIN_W  50
#define GPU_POWER_MAX_W  400

// ✅ Input validation limits
#define MAX_ID_LEN 63
#define MAX_METRIC_NAME_LEN 31
#define MAX_RULES 8

typedef struct {
    double power_cap_w;
    double latency_slo_ms;
    double quality_floor;
} ea_constraints_t;

typedef struct {
    double flops_per_token;
    double mem_bw_per_token;
    double alpha;
    double beta;
    double overhead_j;
} ea_cost_model_t;

typedef enum {
    ACTION_NONE = 0,
    ACTION_DVFS_SCALE,
    ACTION_MOE_REDUCE_K,
    ACTION_LAYER_SKIP,
    ACTION_BATCH_RESIZE,
    ACTION_QUANTIZE
} ea_action_type_t;

typedef struct {
    char metric_name[MAX_METRIC_NAME_LEN + 1];
    char op[4];
    double threshold;
    ea_action_type_t action;
    double action_param;
    double min_value;
    double max_value;
    
    // ✅ NEW: Oscillation prevention
    uint64_t cooldown_ms;
    uint64_t last_triggered_ms;
} ea_rule_t;

typedef struct {
    char model_id[MAX_ID_LEN + 1];
    char ir_version[16];
    uint64_t created_at;
    
    ea_constraints_t constraints;
    ea_cost_model_t  cost_model;
    
    int num_rules;
    ea_rule_t rules[MAX_RULES];
    
    int dvfs_granularity;
    int telemetry_interval_ms;
    int recompile_limit;
} ea_ir_t;

// ✅ Security functions
void safe_copy_string(char* dest, const char* src, size_t max_len);
int clamp_freq(int freq_mhz);
int clamp_power(int power_w);
bool validate_ir(const ea_ir_t* ir);

#endif /* EA_IR_H */
```

---

## 🎯 Day 3 Implementation Priorities

### Critical (Must Have)

1. ✅ `safe_copy_string()` implementation
2. ✅ Hardware limit clamping
3. ✅ Cooldown logic
4. ✅ Input validation

### Important (Should Have)

1. ⬜ Privilege separation architecture
2. ⬜ Rate limiting
3. ⬜ Telemetry access control

### Nice to Have

1. ⬜ Hysteresis implementation
2. ⬜ Audit logging
3. ⬜ Constant-time operations

---

## 📚 References

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **CWE-120**: Buffer Overflow
- **CWE-78**: OS Command Injection
- **Control Theory**: Hysteresis and PID tuning
- **Side-Channel Attacks**: Power analysis (DPA/SPA)

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-11  
**Status**: MANDATORY for production deployment

**⚠️ WARNING**: Implementing EA-AOL without these security measures can result in hardware damage, data loss, or security breaches. This is not optional.
