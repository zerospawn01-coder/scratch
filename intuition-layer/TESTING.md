# Intuition-Layer

## Testing

Run unit tests to verify the three-way routing logic:

```bash
python test_intuition_router.py
```

**Test Coverage**: 14 tests covering:
- Intuition Score = α*complexity + β*memory_distance + γ*uncertainty
- Three-way decision: Skip (score < τ1), Retrieve (τ1 ≤ score < τ2), Reason (score ≥ τ2)
- Threshold boundaries (τ1=0.6, τ2=1.2)
- Complexity estimation
- Uncertainty estimation
- Metrics tracking

All tests use mocked transformers/torch (no GPU required).
All tests pass in < 0.02 seconds.

## Reproducibility

Core routing logic is fully tested without requiring model loading.
For end-to-end tests with real models, see evaluation scripts.
