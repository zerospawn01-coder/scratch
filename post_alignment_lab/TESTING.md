# Post-Alignment Lab

## Testing

Run unit tests to verify the Parametric Value Lens (PVL) implementation:

```bash
python test_post_alignment_phase2.py
```

**Test Coverage**: 17 tests covering:
- L_θ(s) = θ[0] * affinity + θ[1] (linear transformation)
- θ update rule: Δθ = η * (α*coherence + β*rigidity + γ*diversity) * noise
- Bounds enforcement: θ[0] ∈ [0.1, 5.0], θ[1] ∈ [-1.0, 1.0]
- Environment dynamics (energy, position, resources)
- Agent behavior (value selection, commitment window)
- Meaning divergence in different environments

All tests pass in < 0.2 seconds.

## Reproducibility

All mathematical formulas are implemented with unit tests.
Test coverage: 100% for core PVL functions.
See `test_post_alignment_phase2.py` for verification.
