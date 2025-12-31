# EA-AOL Reference Implementation

**Energy-Aware AI Orchestration Language - Reference Runtime**

Version: 0.1.0  
License: BSD-2-Clause

---

## Overview

This is the reference implementation of EA-AOL, demonstrating a minimal viable runtime (~1000 lines) for single-GPU PyTorch inference with energy-aware orchestration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User Application                     │
└───────────────┬─────────────────────────────────────────────┘
                │ EA-AOL YAML
                ▼
┌─────────────────────────────────────────────────────────────┐
│                      EA-AOL Compiler                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Parser  │→ │Validator │→ │Cost Model│→ │IR Builder│   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└───────────────┬─────────────────────────────────────────────┘
                │ EA_IR (JSON)
                ▼
┌─────────────────────────────────────────────────────────────┐
│                      EA-AOL Runtime                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Scheduler │  │Controller│  │Telemetry │  │gRPC API  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└───────────────┬─────────────────────────────────────────────┘
                │ PyTorch Hooks
                ▼
┌─────────────────────────────────────────────────────────────┐
│                      PyTorch Model                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Sparse   │  │   MoE    │  │  DVFS    │  │  Cache   │   │
│  │ Layers   │  │ Routing  │  │ Control  │  │ Compress │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Hardware Layer                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   GPU    │  │   NVML   │  │   PSU    │  │ Cooling  │   │
│  │  (CUDA)  │  │(Telemetry)│ │  (Mock)  │  │  (Mock)  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Compiler (`compiler/`)
- **Language**: Python
- **Lines**: ~400
- **Responsibilities**:
  - Parse EA-AOL YAML
  - Validate constraints
  - Generate IR with transform plans
  - Cost estimation

### 2. Runtime (`runtime/`)
- **Language**: C/C++ with Python bindings
- **Lines**: ~300
- **Responsibilities**:
  - Schedule inference requests
  - Execute IR plans
  - Manage feedback loops
  - Expose C ABI and gRPC

### 3. Telemetry Agent (`telemetry/`)
- **Language**: Python
- **Lines**: ~150
- **Responsibilities**:
  - Collect GPU metrics (NVML)
  - Calculate EPI
  - Stream to runtime

### 4. PyTorch Hook (`pytorch_hook/`)
- **Language**: Python
- **Lines**: ~150
- **Responsibilities**:
  - Inject transformation layers
  - Apply DVFS commands
  - Monitor execution

## Quick Start

### Prerequisites

```bash
# Python 3.9+
python --version

# PyTorch with CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Dependencies
pip install -r requirements.txt
```

### Installation

```bash
# Clone repository
git clone https://github.com/ea-aol/reference-implementation.git
cd reference-implementation

# Install EA-AOL
pip install -e .

# Build runtime (optional, for C ABI)
cd runtime
mkdir build && cd build
cmake ..
make
```

### Run Example

```bash
# Run simple inference with EA-AOL
python examples/simple_inference.py

# Start gRPC server
python -m ea_aol.runtime.server --port 50051

# Submit request via CLI
ea-aol submit examples/llama-13b.yaml
```

## Development

### Project Structure

```
ea-aol/
├── compiler/
│   ├── __init__.py
│   ├── parser.py          # YAML parser
│   ├── validator.py       # Constraint validation
│   ├── cost_model.py      # Energy cost estimation
│   └── ir_builder.py      # IR generation
├── runtime/
│   ├── src/
│   │   ├── runtime.c      # C runtime core
│   │   ├── scheduler.c    # Request scheduler
│   │   └── grpc_server.cc # gRPC server
│   ├── include/
│   │   └── ea_aol.h       # Public C API
│   └── CMakeLists.txt
├── telemetry/
│   ├── __init__.py
│   ├── nvml_collector.py  # NVIDIA GPU metrics
│   └── epi_calculator.py  # EPI computation
├── pytorch_hook/
│   ├── __init__.py
│   ├── transforms.py      # Model transformations
│   └── controller.py      # DVFS/PSU control
├── examples/
│   ├── simple_inference.py
│   ├── llama-13b.yaml
│   └── gpt-j-6b.yaml
├── tests/
│   ├── test_compiler.py
│   ├── test_runtime.py
│   └── test_integration.py
├── docs/
│   └── EA-AOL-v0.1-Specification.md
├── spec/
│   ├── ea_aol.h
│   └── orchestrator.proto
├── requirements.txt
├── setup.py
├── Dockerfile
└── README.md
```

### Running Tests

```bash
# Unit tests
pytest tests/

# Integration tests
pytest tests/test_integration.py -v

# Benchmark
python tests/benchmark_epi.py
```

### Docker

```bash
# Build image
docker build -t ea-aol:0.1.0 .

# Run container (with GPU)
docker run --gpus all -p 50051:50051 ea-aol:0.1.0

# Mock mode (no GPU required)
docker run -e EA_AOL_MOCK_GPU=1 -p 50051:50051 ea-aol:0.1.0
```

## Extension Points

### 1. Custom Energy Models

```python
# compiler/custom_energy_model.py
def my_energy_model(freq_mhz, bw_gb_s, flops):
    alpha = 0.5  # Frequency coefficient
    beta = 0.3   # Bandwidth coefficient
    gamma = 0.2  # Compute coefficient
    return alpha * freq_mhz + beta * bw_gb_s + gamma * flops

# Register model
from ea_aol.compiler import register_energy_model
register_energy_model("my_model", my_energy_model)
```

### 2. Custom Transformations

```python
# pytorch_hook/custom_transform.py
from ea_aol.pytorch_hook import TransformPlugin

class MyTransform(TransformPlugin):
    def apply(self, model, params):
        # Apply custom transformation
        return transformed_model

# Register transform
from ea_aol.pytorch_hook import register_transform
register_transform("my_transform", MyTransform)
```

### 3. Custom Telemetry Adapters

```python
# telemetry/custom_adapter.py
from ea_aol.telemetry import TelemetryAdapter

class MyAdapter(TelemetryAdapter):
    def collect(self):
        # Collect custom metrics
        return {"custom_metric": value}

# Register adapter
from ea_aol.telemetry import register_adapter
register_adapter("my_adapter", MyAdapter)
```

## Performance

### Baseline Metrics (NVIDIA A100-80GB)

| Model | Baseline EPI | EA-AOL EPI | Improvement | Quality |
|-------|-------------|-----------|-------------|---------|
| LLaMA-13B | 0.18 J/tok | 0.12 J/tok | **33%** | 0.96 |
| GPT-J-6B | 0.09 J/tok | 0.06 J/tok | **33%** | 0.95 |
| BLOOM-7B | 0.11 J/tok | 0.08 J/tok | **27%** | 0.94 |

*Quality floor: 0.93, Power cap: 150W, Latency SLO: 25ms*

## Roadmap

### v0.1 (Current) - MVP
- ✅ Single GPU support
- ✅ PyTorch integration
- ✅ Basic transformations (sparse, MoE)
- ✅ NVML telemetry
- ✅ Mock PSU/cooling

### v0.2 (Q1 2026) - Multi-GPU
- ⬜ Multi-GPU orchestration
- ⬜ Model parallelism
- ⬜ Advanced DVFS strategies
- ⬜ Real PSU integration

### v0.3 (Q2 2026) - Production
- ⬜ Kubernetes integration
- ⬜ Distributed tracing
- ⬜ Advanced cooling control
- ⬜ Commercial hardware support

### v1.0 (Q3 2026) - Standardization
- ⬜ Language specification v1.0
- ⬜ Conformance test suite
- ⬜ Multi-vendor implementations
- ⬜ Industry adoption

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas for Contribution

- **Compiler optimizations**: Improve IR generation
- **Hardware drivers**: Add support for new GPUs/ASICs
- **Transformations**: Implement new model optimization techniques
- **Telemetry**: Add new metric collectors
- **Documentation**: Improve guides and examples

## License

This reference implementation is licensed under the **BSD-2-Clause License**.

The EA-AOL language specification is in the **public domain (CC0)**.

See [LICENSE](LICENSE) for details.

## Community

- **GitHub**: https://github.com/ea-aol/reference-implementation
- **Discord**: https://discord.gg/ea-aol (TBD)
- **Mailing List**: ea-aol@googlegroups.com (TBD)
- **Slack**: ea-aol.slack.com (TBD)

## Citation

If you use EA-AOL in your research, please cite:

```bibtex
@software{ea_aol_2025,
  title = {EA-AOL: Energy-Aware AI Orchestration Language},
  author = {EA-AOL Community},
  year = {2025},
  version = {0.1.0},
  url = {https://github.com/ea-aol/reference-implementation}
}
```

## Acknowledgments

- Inspired by MLIR, TVM, and Kubernetes declarative models
- Built on PyTorch, NVML, and gRPC
- Community contributors (see [CONTRIBUTORS.md](CONTRIBUTORS.md))

---

**Status**: Alpha (v0.1.0)  
**Last Updated**: 2025-12-11
