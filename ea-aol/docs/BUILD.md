# EA-AOL v0.1 Starter Kit - Build Instructions

**Version**: 0.1.0  
**Date**: 2025-12-11  
**License**: BSD-2-Clause (Implementation), CC0 (Specification)

---

## Quick Start

### Prerequisites

#### Required
- **Python 3.9+** (for compiler)
- **CMake 3.15+** (for runtime)
- **C++17 compiler** (GCC 7+, Clang 5+, MSVC 2017+)

#### Optional
- **PyTorch 2.0+** (for PyTorch integration)
- **NVML** (for GPU telemetry)
- **gRPC** (for distributed deployment)

---

## Build Steps

### 1. Compiler (Python)

```bash
cd compiler

# Install dependencies
pip install PyYAML

# Test compiler
python compiler.py ../examples/llama-13b.yaml output.json

# Verify output
cat output.json
```

### 2. Runtime (C++)

#### Linux/macOS

```bash
cd runtime
mkdir build && cd build

# Configure
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc)

# Install (optional)
sudo make install

# Run example
./examples/simple_client
```

#### Windows (Visual Studio)

```powershell
cd runtime
mkdir build
cd build

# Configure
cmake .. -G "Visual Studio 16 2019"

# Build
cmake --build . --config Release

# Run example
.\examples\Release\simple_client.exe
```

### 3. Full Integration Test

```bash
# Terminal 1: Compile EA-AOL to IR
python compiler/compiler.py examples/llama-13b.yaml /tmp/llama.ir.json

# Terminal 2: Run runtime with IR
./runtime/build/examples/simple_client

# Expected output:
# [Runtime] Initialized with default config
# [Runtime] Scheduling request: req-001
# [Runtime] Request req-001 is now RUNNING
# State: 1 (RUNNING)
# Power: 120.00 W
```

---

## Development Workflow

### Day 1-3: Setup

```bash
# Clone/create repository
git init ea-aol
cd ea-aol

# Create structure
mkdir -p {compiler,runtime/{src,include,examples},spec,docs,examples,tests}

# Copy starter kit files
# (Files from this document)

# Initialize git
git add .
git commit -m "Initial EA-AOL v0.1 starter kit"
```

### Day 4-7: MVP

**Goal**: End-to-end mock execution

```bash
# 1. Implement compiler
cd compiler
python compiler.py ../examples/llama-13b.yaml test.ir.json

# 2. Build runtime
cd ../runtime
mkdir build && cd build
cmake .. && make

# 3. Run integration
./examples/simple_client
```

**Success Criteria**:
- ✅ Compiler generates valid IR JSON
- ✅ Runtime accepts IR and creates task
- ✅ Status query returns mock metrics

### Day 8-14: PyTorch Integration

**Goal**: Real GPU execution with dynamic transforms

```bash
# 1. Install PyTorch
pip install torch torchvision

# 2. Implement PyTorch hook
cd pytorch_hook
python test_transforms.py

# 3. Run real inference
python ../examples/pytorch_inference.py
```

**Success Criteria**:
- ✅ PyTorch model loads successfully
- ✅ Transforms apply (sparsification visible)
- ✅ NVML reports real power consumption

---

## Testing

### Unit Tests

```bash
# Compiler tests
cd compiler
python -m pytest tests/

# Runtime tests
cd runtime/build
ctest -V
```

### Integration Tests

```bash
# Full pipeline test
./tests/integration/test_e2e.sh
```

### Benchmarks

```bash
# Energy efficiency benchmark
python tests/benchmarks/epi_benchmark.py --model llama-13b --samples 100
```

---

## Troubleshooting

### Compiler Issues

**Problem**: `ModuleNotFoundError: No module named 'yaml'`

```bash
pip install PyYAML
```

**Problem**: `CompilerError: Missing required field`

Check YAML syntax:
```bash
python -c "import yaml; yaml.safe_load(open('your_file.yaml'))"
```

### Runtime Issues

**Problem**: `undefined reference to ea_aol_init`

Ensure library is linked:
```cmake
target_link_libraries(your_target ea_aol)
```

**Problem**: CMake can't find compiler

```bash
# Specify compiler explicitly
cmake .. -DCMAKE_CXX_COMPILER=g++
```

### GPU Issues

**Problem**: `NVML initialization failed`

```bash
# Check NVIDIA driver
nvidia-smi

# Use mock mode
export EA_AOL_MOCK_GPU=1
```

---

## Directory Structure

```
ea-aol/
├── compiler/
│   ├── compiler.py          # Main compiler
│   ├── parser.py            # YAML parser (from existing)
│   ├── ir_builder.py        # IR builder (from existing)
│   └── __init__.py
├── runtime/
│   ├── CMakeLists.txt       # Build configuration
│   ├── include/
│   │   └── ea_aol.h         # Public C API
│   ├── src/
│   │   └── ea_aol_runtime.cpp  # Runtime implementation
│   └── examples/
│       ├── CMakeLists.txt
│       └── simple_client.c  # Example client
├── spec/
│   ├── EA-AOL-v0.1-EBNF-Grammar.md
│   ├── EA-IR-Specification.md
│   ├── ea_aol.h             # C API header
│   └── orchestrator.proto   # gRPC protocol
├── examples/
│   ├── llama-13b.yaml       # Sample EA-AOL
│   ├── demo_compiler.py     # Compiler demo
│   └── simple_inference.py  # PyTorch demo
├── docs/
│   ├── EA-AOL-v0.1-Specification.md
│   ├── QUICKSTART.md
│   ├── ROADMAP.md
│   └── BUILD.md             # This file
├── tests/
│   ├── test_compiler.py
│   └── test_integration.py
├── README.md
├── LICENSE
└── requirements.txt
```

---

## Next Steps

### Immediate (This Week)

1. ✅ **Setup**: Create repository structure
2. ✅ **Compiler**: Implement YAML → IR compilation
3. ✅ **Runtime**: Implement basic C API
4. ⬜ **Integration**: Connect compiler + runtime

### Short-term (Next 2 Weeks)

1. ⬜ **PyTorch Hook**: Implement dynamic transforms
2. ⬜ **Telemetry**: Real NVML integration
3. ⬜ **DVFS**: Real GPU frequency control
4. ⬜ **Tests**: Comprehensive test suite

### Medium-term (Next Month)

1. ⬜ **gRPC Server**: Distributed deployment
2. ⬜ **Kubernetes**: Operator implementation
3. ⬜ **Benchmarks**: Performance validation
4. ⬜ **Documentation**: Complete user guide

---

## Contributing

### Code Style

- **Python**: PEP 8
- **C++**: Google C++ Style Guide
- **Commits**: Conventional Commits

### Pull Request Process

1. Fork repository
2. Create feature branch
3. Write tests
4. Submit PR with description

---

## Support

- **GitHub Issues**: https://github.com/ea-aol/reference-implementation/issues
- **Documentation**: `docs/`
- **Examples**: `examples/`

---

**Last Updated**: 2025-12-11  
**Status**: Active Development
