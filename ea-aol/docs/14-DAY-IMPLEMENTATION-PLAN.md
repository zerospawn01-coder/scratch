# EA-AOL 14-Day Implementation Plan

**Version**: 0.1.0  
**Date**: 2025-12-11  
**Goal**: Working MoE Top-K degradation demo with EPI visualization

---

## Overview

This plan delivers a **working proof-of-concept** in 14 days:

- **Day 1-3**: Core IR & ABI
- **Day 4-7**: Metrics & EPI
- **Day 8-14**: MoE Control Demo

**Target**: <1000 lines of code, demonstrable energy-aware control

---

## Phase 1: The Core (Day 1-3)

### Goal
Establish the **language foundation**: IR structure, compiler, and runtime stub.

### Tasks

#### Day 1: IR Definition

**File**: `runtime/include/ea_ir.h`

✅ **Status**: COMPLETE

- [x] Define `ea_constraints_t` structure
- [x] Define `ea_cost_model_t` structure
- [x] Define `ea_rule_t` and `ea_action_type_t`
- [x] Define root `ea_ir_t` structure
- [x] Add serialization function declarations

**Deliverable**: Header file that compiles without errors

```bash
# Test compilation
gcc -c -I runtime/include runtime/include/ea_ir.h -o /dev/null
```

#### Day 2: Compiler Implementation

**File**: `compiler/ir_compiler.py`

**Tasks**:
- [ ] Implement YAML → `ea_ir_t` JSON converter
- [ ] Add validation for required fields
- [ ] Generate control rules from policy section
- [ ] Calculate cost model parameters

**Code Skeleton**:

```python
#!/usr/bin/env python3
"""
EA-AOL IR Compiler
Converts YAML to ea_ir_t compatible JSON
"""

import yaml
import json
import sys
from datetime import datetime

def compile_to_ir(yaml_path):
    # Load YAML
    with open(yaml_path, 'r') as f:
        spec = yaml.safe_load(f)
    
    # Extract sections
    inference = spec['inference']
    profile = spec.get('profile', {})
    policy = spec.get('policy', {})
    
    # Build IR
    ir = {
        'model_id': inference['model_id'],
        'ir_version': '0.1.0',
        'created_at': int(datetime.utcnow().timestamp()),
        
        'constraints': {
            'power_cap_w': float(str(inference['power_cap']).rstrip('W')),
            'latency_slo_ms': float(inference['latency_slo_ms']),
            'quality_floor': float(inference['quality_floor'])
        },
        
        'cost_model': extract_cost_model(profile),
        'num_rules': 0,
        'rules': generate_rules(policy, inference),
        'dvfs_granularity': 0,  # batch
        'telemetry_interval_ms': 500,
        'recompile_limit': 3
    }
    
    ir['num_rules'] = len(ir['rules'])
    
    return ir

def extract_cost_model(profile):
    cost = profile.get('cost_model', {})
    return {
        'flops_per_token': float(cost.get('flops_per_token', 1.4e10)),
        'mem_bw_per_token': float(cost.get('mem_bw_per_token', 800e6)),
        'alpha': float(cost.get('alpha_j_per_flop', 1.0e-12)),
        'beta': float(cost.get('beta_j_per_byte', 5.0e-9)),
        'overhead_j': 0.001
    }

def generate_rules(policy, inference):
    rules = []
    
    # Generate rule from policy strategies
    strategies = policy.get('strategies', [])
    for strat in strategies:
        if strat['name'] == 'moe_degrade':
            rule = {
                'metric_name': 'power_w',
                'op': '>',
                'threshold': float(str(inference['power_cap']).rstrip('W')),
                'action': 2,  # ACTION_MOE_REDUCE_K
                'action_param': float(strat.get('step', 1)),
                'min_value': float(strat.get('min_k', 1)),
                'max_value': 8.0
            }
            rules.append(rule)
    
    return rules

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python ir_compiler.py <input.yaml> [output.json]")
        sys.exit(1)
    
    ir = compile_to_ir(sys.argv[1])
    
    if len(sys.argv) > 2:
        with open(sys.argv[2], 'w') as f:
            json.dump(ir, f, indent=2)
        print(f"[OK] Compiled to {sys.argv[2]}")
    else:
        print(json.dumps(ir, indent=2))
```

**Test**:

```bash
python compiler/ir_compiler.py examples/mixtral_eco.yaml output.json
cat output.json
```

#### Day 3: Runtime Stub

**File**: `runtime/src/runtime_stub.cpp`

**Tasks**:
- [ ] Implement `ea_aol_init_from_ir()`
- [ ] Implement `ea_aol_tick()` (stub version)
- [ ] Implement `ea_aol_destroy()`

**Code Skeleton**:

```cpp
#include "ea_aol.h"
#include "ea_ir.h"
#include <iostream>
#include <cstring>

struct ea_ctx_t {
    ea_ir_t ir;
    int current_k;
    double current_freq;
};

ea_ctx_t* ea_aol_init_from_ir(const ea_ir_t* ir) {
    if (!ir) return nullptr;
    
    auto* ctx = new ea_ctx_t();
    std::memcpy(&ctx->ir, ir, sizeof(ea_ir_t));
    ctx->current_k = 4;  // Default MoE k
    ctx->current_freq = 1500.0;  // Default GPU freq (MHz)
    
    std::cout << "[Runtime] Initialized with model: " << ir->model_id << std::endl;
    std::cout << "[Runtime] Power cap: " << ir->constraints.power_cap_w << " W" << std::endl;
    
    return ctx;
}

ea_advice_t ea_aol_tick(ea_ctx_t* ctx, double current_latency, double current_power) {
    ea_advice_t advice = {-1, -1.0};
    
    if (!ctx) return advice;
    
    // Check rules
    for (int i = 0; i < ctx->ir.num_rules; i++) {
        const ea_rule_t& rule = ctx->ir.rules[i];
        
        double metric_value = 0.0;
        if (strcmp(rule.metric_name, "power_w") == 0) {
            metric_value = current_power;
        } else if (strcmp(rule.metric_name, "latency_ms") == 0) {
            metric_value = current_latency;
        }
        
        bool triggered = false;
        if (strcmp(rule.op, ">") == 0) {
            triggered = (metric_value > rule.threshold);
        }
        
        if (triggered) {
            if (rule.action == ACTION_MOE_REDUCE_K) {
                int new_k = ctx->current_k - (int)rule.action_param;
                if (new_k >= (int)rule.min_value) {
                    ctx->current_k = new_k;
                    advice.new_top_k = new_k;
                    std::cout << "[Runtime] Power exceeded, reducing k: " 
                              << (new_k + 1) << " → " << new_k << std::endl;
                }
            }
        }
    }
    
    return advice;
}

void ea_aol_destroy(ea_ctx_t* ctx) {
    delete ctx;
    std::cout << "[Runtime] Destroyed" << std::endl;
}
```

**Test**:

```bash
cd runtime/build
cmake .. && make
./test_runtime_stub
```

### Phase 1 Deliverables

- ✅ `ea_ir.h` header
- ⬜ `ir_compiler.py` working
- ⬜ `runtime_stub.cpp` compiling
- ⬜ End-to-end: YAML → JSON → Load in C++

---

## Phase 2: The Metrics (Day 4-7)

### Goal
Implement **EPI calculation** and **telemetry collection**.

### Tasks

#### Day 4: Telemetry Mock

**File**: `telemetry/telemetry_mock.py`

**Tasks**:
- [ ] Generate random power values (100-200W)
- [ ] Generate random throughput (30-60 tokens/s)
- [ ] Calculate EPI = power / throughput
- [ ] Output JSON telemetry

**Code**:

```python
#!/usr/bin/env python3
"""
Mock Telemetry Generator
Simulates GPU power and throughput for testing
"""

import random
import time
import json

class TelemetryMock:
    def __init__(self, base_power=150.0, base_throughput=45.0):
        self.base_power = base_power
        self.base_throughput = base_throughput
        self.current_k = 4
    
    def set_k(self, k):
        """Simulate effect of reducing k"""
        self.current_k = k
    
    def collect(self):
        # Simulate: lower k → lower power, lower throughput
        k_factor = self.current_k / 4.0
        
        power = self.base_power * k_factor + random.uniform(-10, 10)
        throughput = self.base_throughput * k_factor + random.uniform(-5, 5)
        
        epi = power / throughput if throughput > 0 else 0
        
        return {
            'timestamp': int(time.time()),
            'metrics': {
                'power_w': round(power, 2),
                'throughput_tps': round(throughput, 2),
                'epi_j_per_token': round(epi, 3),
                'latency_p99_ms': round(random.uniform(40, 55), 2)
            },
            'status': {
                'active_k': self.current_k
            }
        }

if __name__ == '__main__':
    mock = TelemetryMock()
    
    for i in range(10):
        telemetry = mock.collect()
        print(json.dumps(telemetry, indent=2))
        time.sleep(0.5)
        
        # Simulate k reduction after 5 iterations
        if i == 5:
            mock.set_k(3)
            print("\n[MOCK] Reduced k to 3\n")
```

**Test**:

```bash
python telemetry/telemetry_mock.py
```

#### Day 5-6: Runtime Core Logic

**File**: `runtime/src/runtime_core.cpp`

**Tasks**:
- [ ] Enhance `ea_aol_tick()` with real control logic
- [ ] Add EPI estimation
- [ ] Add rule evaluation
- [ ] Add state tracking

**Enhanced Code**:

```cpp
ea_advice_t ea_aol_tick(ea_ctx_t* ctx, double current_latency, double current_power) {
    ea_advice_t advice = {-1, -1.0};
    
    if (!ctx) return advice;
    
    // Calculate estimated EPI
    double throughput_est = 45.0;  // Mock for now
    double epi_est = current_power / throughput_est;
    
    std::cout << "[Runtime] Power: " << current_power << " W, "
              << "EPI: " << epi_est << " J/token" << std::endl;
    
    // Evaluate rules
    for (int i = 0; i < ctx->ir.num_rules; i++) {
        const ea_rule_t& rule = ctx->ir.rules[i];
        
        double metric_value = 0.0;
        if (strcmp(rule.metric_name, "power_w") == 0) {
            metric_value = current_power;
        }
        
        bool triggered = false;
        if (strcmp(rule.op, ">") == 0) {
            triggered = (metric_value > rule.threshold);
        }
        
        if (triggered && rule.action == ACTION_MOE_REDUCE_K) {
            int new_k = ctx->current_k - (int)rule.action_param;
            if (new_k >= (int)rule.min_value && new_k < ctx->current_k) {
                ctx->current_k = new_k;
                advice.new_top_k = new_k;
                
                std::cout << "[Runtime] ⚠️  Power cap exceeded!" << std::endl;
                std::cout << "[Runtime] 🔧 Action: Reduce MoE k → " << new_k << std::endl;
            }
        }
    }
    
    return advice;
}
```

#### Day 7: Integration Test

**File**: `tests/test_phase2.cpp`

**Test**:

```cpp
#include "ea_aol.h"
#include "ea_ir.h"
#include <iostream>

int main() {
    // Create IR
    ea_ir_t ir = {};
    strcpy(ir.model_id, "mixtral-test");
    ir.constraints.power_cap_w = 180.0;
    ir.num_rules = 1;
    
    ir.rules[0] = {
        .metric_name = "power_w",
        .op = ">",
        .threshold = 180.0,
        .action = ACTION_MOE_REDUCE_K,
        .action_param = 1.0,
        .min_value = 1.0,
        .max_value = 8.0
    };
    
    // Initialize runtime
    ea_ctx_t* ctx = ea_aol_init_from_ir(&ir);
    
    // Simulate power spike
    std::cout << "\n=== Simulating power spike ===" << std::endl;
    
    for (int i = 0; i < 5; i++) {
        double power = 150.0 + i * 15.0;  // Gradually increase
        double latency = 45.0;
        
        ea_advice_t advice = ea_aol_tick(ctx, latency, power);
        
        if (advice.new_top_k != -1) {
            std::cout << "✓ Runtime advised k=" << advice.new_top_k << std::endl;
        }
        
        std::cout << std::endl;
    }
    
    ea_aol_destroy(ctx);
    return 0;
}
```

**Expected Output**:

```
[Runtime] Initialized with model: mixtral-test
[Runtime] Power cap: 180 W

=== Simulating power spike ===
[Runtime] Power: 150 W, EPI: 3.33 J/token

[Runtime] Power: 165 W, EPI: 3.67 J/token

[Runtime] Power: 180 W, EPI: 4.00 J/token

[Runtime] Power: 195 W, EPI: 4.33 J/token
[Runtime] ⚠️  Power cap exceeded!
[Runtime] 🔧 Action: Reduce MoE k → 3
✓ Runtime advised k=3

[Runtime] Power: 210 W, EPI: 4.67 J/token
[Runtime] ⚠️  Power cap exceeded!
[Runtime] 🔧 Action: Reduce MoE k → 2
✓ Runtime advised k=2
```

### Phase 2 Deliverables

- ⬜ Telemetry mock working
- ⬜ EPI calculation implemented
- ⬜ Control logic functional
- ⬜ Integration test passing

---

## Phase 3: The Demo (Day 8-14)

### Goal
**Working MoE control** with **real-time visualization**.

### Tasks

#### Day 8-10: PyTorch Hook

**File**: `pytorch_hook/moe_controller.py`

**Tasks**:
- [ ] Load Mixtral or tiny MoE model
- [ ] Hook into forward pass
- [ ] Apply runtime advice (k value)
- [ ] Collect real metrics

**Code**:

```python
#!/usr/bin/env python3
"""
PyTorch MoE Controller
Integrates EA-AOL runtime with PyTorch MoE models
"""

import torch
import torch.nn as nn
from transformers import AutoModelForCausalLM, AutoTokenizer
import subprocess
import json
import time

class MoEController:
    def __init__(self, model_name, ir_path):
        self.model = AutoModelForCausalLM.from_pretrained(model_name)
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        
        # Load IR
        with open(ir_path, 'r') as f:
            self.ir = json.load(f)
        
        self.current_k = 4
        self.power_cap = self.ir['constraints']['power_cap_w']
        
        # Hook into MoE layers
        self._hook_moe_layers()
    
    def _hook_moe_layers(self):
        """Hook into MoE forward pass"""
        for name, module in self.model.named_modules():
            if 'moe' in name.lower() or 'expert' in name.lower():
                module.register_forward_hook(self._moe_forward_hook)
    
    def _moe_forward_hook(self, module, input, output):
        """Modify MoE routing based on current k"""
        # This is model-specific
        # For Mixtral: modify top_k parameter
        if hasattr(module, 'top_k'):
            module.top_k = self.current_k
    
    def generate(self, prompt, max_length=100):
        """Generate with EA-AOL control"""
        inputs = self.tokenizer(prompt, return_tensors="pt")
        
        start_time = time.time()
        
        # Simulate power monitoring
        power = self._get_mock_power()
        
        # Check if we need to reduce k
        if power > self.power_cap:
            self.current_k = max(1, self.current_k - 1)
            print(f"[Controller] Power {power:.1f}W > {self.power_cap}W, reducing k → {self.current_k}")
        
        # Generate
        outputs = self.model.generate(
            **inputs,
            max_length=max_length,
            do_sample=True
        )
        
        elapsed = time.time() - start_time
        tokens = outputs.shape[1] - inputs['input_ids'].shape[1]
        throughput = tokens / elapsed
        epi = power / throughput
        
        print(f"[Controller] Generated {tokens} tokens in {elapsed:.2f}s")
        print(f"[Controller] EPI: {epi:.3f} J/token")
        
        return self.tokenizer.decode(outputs[0])
    
    def _get_mock_power(self):
        """Mock power measurement"""
        # In real implementation, use NVML
        base = 150.0
        k_factor = self.current_k / 4.0
        return base * k_factor

# Usage
if __name__ == '__main__':
    controller = MoEController(
        model_name="mistralai/Mixtral-8x7B-v0.1",
        ir_path="output.json"
    )
    
    result = controller.generate("The future of AI is")
    print(result)
```

#### Day 11-12: Visualization

**File**: `tools/epi_visualizer.py`

**Code**:

```python
#!/usr/bin/env python3
"""
Real-time EPI Visualization
"""

import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.gridspec import GridSpec
import json
import time
from collections import deque

class EPIVisualizer:
    def __init__(self, max_points=60):
        self.max_points = max_points
        
        # Data buffers
        self.time_data = deque(maxlen=max_points)
        self.epi_data = deque(maxlen=max_points)
        self.power_data = deque(maxlen=max_points)
        self.k_data = deque(maxlen=max_points)
        
        # Setup plot
        self.fig = plt.figure(figsize=(12, 8))
        gs = GridSpec(3, 1, figure=self.fig, hspace=0.3)
        
        self.ax_epi = self.fig.add_subplot(gs[0, 0])
        self.ax_power = self.fig.add_subplot(gs[1, 0])
        self.ax_k = self.fig.add_subplot(gs[2, 0])
        
        self.start_time = time.time()
    
    def update(self, frame):
        # Fetch telemetry (from mock or real source)
        telemetry = self._fetch_telemetry()
        
        current_time = time.time() - self.start_time
        self.time_data.append(current_time)
        self.epi_data.append(telemetry['metrics']['epi_j_per_token'])
        self.power_data.append(telemetry['metrics']['power_w'])
        self.k_data.append(telemetry['status']['active_k'])
        
        # Plot EPI
        self.ax_epi.clear()
        self.ax_epi.plot(list(self.time_data), list(self.epi_data), 'b-', linewidth=2)
        self.ax_epi.axhline(y=4.0, color='r', linestyle='--', label='Target: 4.0 J/tok')
        self.ax_epi.set_ylabel('EPI (J/token)', fontsize=12)
        self.ax_epi.set_title('Energy Per Inference', fontsize=14, fontweight='bold')
        self.ax_epi.legend()
        self.ax_epi.grid(True, alpha=0.3)
        
        # Plot Power
        self.ax_power.clear()
        self.ax_power.plot(list(self.time_data), list(self.power_data), 'g-', linewidth=2)
        self.ax_power.axhline(y=180.0, color='r', linestyle='--', label='Cap: 180W')
        self.ax_power.set_ylabel('Power (W)', fontsize=12)
        self.ax_power.set_title('GPU Power Consumption', fontsize=14, fontweight='bold')
        self.ax_power.legend()
        self.ax_power.grid(True, alpha=0.3)
        
        # Plot k
        self.ax_k.clear()
        self.ax_k.step(list(self.time_data), list(self.k_data), 'orange', linewidth=2, where='post')
        self.ax_k.set_ylabel('MoE Top-K', fontsize=12)
        self.ax_k.set_xlabel('Time (s)', fontsize=12)
        self.ax_k.set_title('MoE Expert Selection', fontsize=14, fontweight='bold')
        self.ax_k.set_ylim([0, 5])
        self.ax_k.grid(True, alpha=0.3)
    
    def _fetch_telemetry(self):
        # Mock telemetry for demo
        from telemetry.telemetry_mock import TelemetryMock
        if not hasattr(self, 'mock'):
            self.mock = TelemetryMock()
        return self.mock.collect()
    
    def run(self):
        ani = animation.FuncAnimation(
            self.fig, self.update, interval=500, blit=False
        )
        plt.tight_layout()
        plt.show()

if __name__ == '__main__':
    viz = EPIVisualizer()
    viz.run()
```

#### Day 13-14: Integration & Demo

**File**: `examples/moe_demo.py`

**Complete Demo**:

```python
#!/usr/bin/env python3
"""
EA-AOL MoE Degradation Demo
Complete end-to-end demonstration
"""

import sys
import time
import threading
from pytorch_hook.moe_controller import MoEController
from tools.epi_visualizer import EPIVisualizer

def run_inference_loop(controller):
    """Run continuous inference"""
    prompts = [
        "The future of AI is",
        "Energy efficiency in computing",
        "Sustainable machine learning"
    ]
    
    for i in range(10):
        prompt = prompts[i % len(prompts)]
        print(f"\n=== Iteration {i+1} ===")
        result = controller.generate(prompt, max_length=50)
        print(f"Result: {result[:100]}...")
        time.sleep(2)

def main():
    print("=" * 60)
    print("EA-AOL MoE Degradation Demo")
    print("=" * 60)
    
    # Initialize controller
    controller = MoEController(
        model_name="mistralai/Mixtral-8x7B-v0.1",
        ir_path="output.json"
    )
    
    # Start inference in background
    inference_thread = threading.Thread(
        target=run_inference_loop,
        args=(controller,)
    )
    inference_thread.daemon = True
    inference_thread.start()
    
    # Start visualization
    viz = EPIVisualizer()
    viz.run()

if __name__ == '__main__':
    main()
```

**Run Demo**:

```bash
# 1. Compile IR
python compiler/ir_compiler.py examples/mixtral_eco.yaml output.json

# 2. Run demo
python examples/moe_demo.py
```

**Expected Behavior**:

1. **Initial State**: k=4, Power ~150W, EPI ~3.3 J/token
2. **Load Increase**: Power rises to 195W
3. **Control Action**: Runtime reduces k to 3
4. **Power Drop**: Power falls to ~165W, EPI ~3.7 J/token
5. **Visualization**: Real-time graphs show the adaptation

### Phase 3 Deliverables

- ⬜ PyTorch hook working
- ⬜ MoE k control functional
- ⬜ Real-time visualization
- ⬜ Complete demo runnable

---

## Success Criteria

### Technical

- [ ] Compiler generates valid IR JSON
- [ ] Runtime loads IR and evaluates rules
- [ ] Control actions modify model behavior
- [ ] EPI calculation is accurate
- [ ] Visualization shows real-time data

### Demonstrable

- [ ] Power cap violation triggers k reduction
- [ ] EPI improves after control action
- [ ] Quality degradation is measurable
- [ ] System is stable under load

### Code Quality

- [ ] Total lines < 1000
- [ ] All components compile/run
- [ ] Basic error handling
- [ ] Documented interfaces

---

## File Checklist

### Core (Day 1-3)

- [x] `runtime/include/ea_ir.h`
- [ ] `compiler/ir_compiler.py`
- [ ] `runtime/src/runtime_stub.cpp`
- [ ] `runtime/include/ea_aol.h` (updated)

### Metrics (Day 4-7)

- [ ] `telemetry/telemetry_mock.py`
- [ ] `runtime/src/runtime_core.cpp`
- [ ] `tests/test_phase2.cpp`

### Demo (Day 8-14)

- [ ] `pytorch_hook/moe_controller.py`
- [ ] `tools/epi_visualizer.py`
- [ ] `examples/moe_demo.py`
- [ ] `examples/mixtral_eco.yaml`

---

## Next Steps

1. ✅ **Day 1**: IR header complete
2. ⬜ **Day 2**: Implement `ir_compiler.py`
3. ⬜ **Day 3**: Implement `runtime_stub.cpp`
4. ⬜ **Day 4**: Create telemetry mock
5. ⬜ **Day 5-6**: Enhance runtime logic
6. ⬜ **Day 7**: Integration test
7. ⬜ **Day 8-10**: PyTorch hook
8. ⬜ **Day 11-12**: Visualization
9. ⬜ **Day 13-14**: Final demo

---

**Status**: Day 1 Complete ✅  
**Next**: Implement IR Compiler (Day 2)

**Ready to proceed with Day 2 implementation?**
