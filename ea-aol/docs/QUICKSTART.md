# EA-AOL Quick Start Guide

Get started with EA-AOL in 5 minutes!

## Installation

```bash
# Clone repository
git clone https://github.com/ea-aol/reference-implementation.git
cd reference-implementation

# Install dependencies
pip install -r requirements.txt

# Install EA-AOL
pip install -e .
```

## Your First EA-AOL Program

### 1. Create an EA-AOL Declaration

Create `my_inference.yaml`:

```yaml
inference:
  model_id: "my-model"
  power_cap: 100W
  latency_slo_ms: 50
  quality_floor: 0.90
  orchestrator:
    layers: ["sparse"]
    monitoring: ["EPI"]
```

### 2. Run Inference

```python
from compiler import parse_ea_aol, build_ir
from pytorch_hook import build_transform_pipeline
import torch.nn as nn

# Parse EA-AOL
decl = parse_ea_aol("my_inference.yaml")
ir = build_ir(decl)

# Apply to your model
model = YourModel()
pipeline = build_transform_pipeline(ir.transforms)
model = pipeline.apply(model)

# Run inference as usual
output = model(input_data)
```

### 3. Monitor Energy

```python
from telemetry import NVMLCollector, EPICalculator

collector = NVMLCollector(mock_mode=True)
calculator = EPICalculator()

# During inference
metrics = collector.collect()
calculator.update(metrics, tokens_generated=10)

print(f"EPI: {calculator.get_epi():.4f} J/token")
```

## Run Example

```bash
python examples/simple_inference.py
```

## Next Steps

- Read the [full specification](docs/EA-AOL-v0.1-Specification.md)
- Explore [examples](examples/)
- Check the [roadmap](docs/ROADMAP.md)
- Join the community (Discord link TBD)

## Docker

```bash
# Build image
docker build -t ea-aol:0.1.0 .

# Run example
docker run ea-aol:0.1.0
```

## Troubleshooting

### No GPU Available
Set mock mode:
```python
collector = NVMLCollector(mock_mode=True)
```

### Import Errors
Make sure EA-AOL is installed:
```bash
pip install -e .
```

## Support

- GitHub Issues: https://github.com/ea-aol/reference-implementation/issues
- Documentation: (TBD)
- Discord: (TBD)
