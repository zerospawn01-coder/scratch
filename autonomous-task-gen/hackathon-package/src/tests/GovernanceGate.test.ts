/**
 * GovernanceGate.test.ts – Unit tests for RGO Governance Layer
 */

import { describe, expect, it } from 'vitest';
import { GovernanceGate } from '../services/GovernanceGate';
import type {
  FormalizedHypothesis,
  ExperimentSpec,
  ExperimentResult,
  ResearchMetric,
} from '../types/rgo';

const gate = new GovernanceGate();

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function metric(overrides?: Partial<ResearchMetric>): ResearchMetric {
  return {
    metricId: 'm1',
    name: 'Recall Accuracy',
    unit: 'percent',
    operator: 'GTE',
    threshold: 70,
    isReproducibilityMetric: true,
    ...overrides,
  };
}

function hypothesis(overrides?: Partial<FormalizedHypothesis>): FormalizedHypothesis {
  return {
    hypothesisId: 'hyp_1',
    intentId: 'intent_1',
    statement: 'Caffeine increases recall by ≥10%.',
    nullHypothesis: 'Caffeine has no effect on recall.',
    metrics: [metric()],
    constraints: ['double-blind', 'controlled dosage'],
    causalModel: undefined,
    ...overrides,
  };
}

function spec(overrides?: Partial<ExperimentSpec>): ExperimentSpec {
  return {
    experimentId: 'exp_1',
    hypothesisId: 'hyp_1',
    procedure: ['Select 100 participants', 'Administer 200mg caffeine', 'Test recall after 30 min'],
    dataRequirements: ['recall_scores.csv'],
    expectedResults: { m1: 75 },
    randomSeed: 42,
    ...overrides,
  };
}

function result(overrides?: Partial<ExperimentResult>): ExperimentResult {
  return {
    experimentId: 'exp_1',
    observedValues: { m1: 78 },
    executedAt: '2026-01-01T12:00:00.000Z',
    reproducibilityHash: 'rep_abc123',
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Gate① – Pre-execution
// ---------------------------------------------------------------------------

describe('GovernanceGate.evaluatePreExecution', () => {
  it('passes a well-formed hypothesis with one reproducibility metric', () => {
    const r = gate.evaluatePreExecution(hypothesis());
    expect(r.status).toBe('PASS');
    expect(r.violations).toHaveLength(0);
    expect(r.kind).toBe('PRE_EXECUTION');
  });

  it('fails when metrics array is empty (MISSING_METRIC)', () => {
    const r = gate.evaluatePreExecution(hypothesis({ metrics: [] }));
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'MISSING_METRIC')).toBe(true);
  });

  it('fails when no reproducibility metric is declared (REPRODUCIBILITY_FAILED)', () => {
    const nonReproMetric = metric({ isReproducibilityMetric: false });
    const r = gate.evaluatePreExecution(hypothesis({ metrics: [nonReproMetric] }));
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'REPRODUCIBILITY_FAILED')).toBe(true);
  });

  it('fails when a metric has a non-finite threshold (METRIC_INTEGRITY_BREACH)', () => {
    const badMetric = metric({ threshold: Infinity, isReproducibilityMetric: true });
    const r = gate.evaluatePreExecution(hypothesis({ metrics: [badMetric] }));
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'METRIC_INTEGRITY_BREACH')).toBe(true);
  });

  it('fails when null hypothesis is empty (SILENT_ASSUMPTION)', () => {
    const r = gate.evaluatePreExecution(hypothesis({ nullHypothesis: '' }));
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'SILENT_ASSUMPTION')).toBe(true);
  });

  it('fails when multiple metrics exist without a causal model (SILENT_ASSUMPTION)', () => {
    const m2 = metric({ metricId: 'm2', name: 'Reaction Time', unit: 'ms', operator: 'LT', threshold: 300 });
    const r = gate.evaluatePreExecution(
      hypothesis({ metrics: [metric(), m2], causalModel: undefined })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'SILENT_ASSUMPTION' && v.path === 'hypothesis.causalModel')).toBe(true);
  });

  it('passes multiple metrics when a causal model is provided', () => {
    const m2 = metric({ metricId: 'm2', name: 'Reaction Time', unit: 'ms', operator: 'LT', threshold: 300, isReproducibilityMetric: false });
    const r = gate.evaluatePreExecution(
      hypothesis({
        metrics: [metric(), m2],
        causalModel: 'Caffeine → Recall via Adenosine suppression, not confounded by Stress',
      })
    );
    expect(r.status).toBe('PASS');
  });
});

// ---------------------------------------------------------------------------
// Gate② – Post-execution
// ---------------------------------------------------------------------------

describe('GovernanceGate.evaluatePostExecution', () => {
  it('passes when all metrics are observed and within bounds', () => {
    const r = gate.evaluatePostExecution(hypothesis(), spec(), result());
    expect(r.status).toBe('PASS');
    expect(r.violations).toHaveLength(0);
    expect(r.kind).toBe('POST_EXECUTION');
  });

  it('fails when reproducibility hash is missing (REPRODUCIBILITY_FAILED)', () => {
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec(),
      result({ reproducibilityHash: '' })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'REPRODUCIBILITY_FAILED')).toBe(true);
  });

  it('fails when a required metric observation is missing (MISSING_METRIC)', () => {
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec(),
      result({ observedValues: {} })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'MISSING_METRIC')).toBe(true);
  });

  it('fails when observed value does not satisfy the metric operator (METRIC_INTEGRITY_BREACH)', () => {
    // metric requires GTE 70; observed 50 fails
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec(),
      result({ observedValues: { m1: 50 } })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'METRIC_INTEGRITY_BREACH')).toBe(true);
  });

  it('fails when metric drifts more than 50% from baseline (P_HACKING_RISK)', () => {
    // expected=75, observed=200 → drift ≈ 167%
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec({ expectedResults: { m1: 75 } }),
      result({ observedValues: { m1: 200 } })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'P_HACKING_RISK')).toBe(true);
  });

  it('fails when result contains an unknown metric key (DATA_LEAK_DETECTED)', () => {
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec(),
      result({ observedValues: { m1: 78, unknown_metric: 99 } })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.some(v => v.code === 'DATA_LEAK_DETECTED')).toBe(true);
  });

  it('collects multiple violations in a single pass', () => {
    const r = gate.evaluatePostExecution(
      hypothesis(),
      spec(),
      result({
        reproducibilityHash: '',
        observedValues: { m1: 50, extra: 1 },
      })
    );
    expect(r.status).toBe('FAIL');
    expect(r.violations.length).toBeGreaterThan(1);
  });
});
