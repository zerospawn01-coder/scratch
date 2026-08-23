/**
 * ResearchCompiler.test.ts – Unit tests for RGO Intent & Formalization
 */

import { describe, expect, it } from 'vitest';
import { ResearchCompiler } from '../services/ResearchCompiler';
import type { ResearchIntent, FormalizedHypothesis, ResearchMetric } from '../types/rgo';

const compiler = new ResearchCompiler();

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function validIntent(overrides?: Partial<ResearchIntent>): Partial<ResearchIntent> {
  return {
    problemStatement: 'Does caffeine improve short-term memory recall in adults?',
    importance: 'Caffeine is consumed globally; evidence on memory is conflicting.',
    keywords: ['caffeine', 'memory', 'cognition'],
    ...overrides,
  };
}

function validMetric(overrides?: Partial<ResearchMetric>): ResearchMetric {
  return {
    metricId: 'metric_recall',
    name: 'Recall Accuracy',
    unit: 'percent',
    operator: 'GTE',
    threshold: 70,
    isReproducibilityMetric: true,
    ...overrides,
  };
}

function validHypothesis(intentId = 'intent_test', overrides?: Partial<FormalizedHypothesis>): Partial<FormalizedHypothesis> {
  return {
    statement: 'Caffeine consumption increases recall accuracy by at least 10% compared to placebo.',
    nullHypothesis: 'Caffeine consumption has no significant effect on recall accuracy.',
    metrics: [validMetric()],
    constraints: ['double-blind', 'controlled dosage: 200mg'],
    intentId,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// validateIntent
// ---------------------------------------------------------------------------

describe('ResearchCompiler.validateIntent', () => {
  it('returns no violations for a valid intent', () => {
    const v = compiler.validateIntent(validIntent());
    expect(v).toHaveLength(0);
  });

  it('rejects missing problemStatement', () => {
    const v = compiler.validateIntent(validIntent({ problemStatement: '' }));
    expect(v.some(x => x.code === 'INVALID_HYPOTHESIS')).toBe(true);
  });

  it('rejects trivially short problemStatement', () => {
    const v = compiler.validateIntent(validIntent({ problemStatement: 'Does it work?' }));
    expect(v.some(x => x.code === 'SILENT_ASSUMPTION')).toBe(true);
  });

  it('rejects missing importance', () => {
    const v = compiler.validateIntent(validIntent({ importance: '' }));
    expect(v.some(x => x.code === 'SILENT_ASSUMPTION')).toBe(true);
  });

  it('rejects empty keywords array', () => {
    const v = compiler.validateIntent(validIntent({ keywords: [] }));
    expect(v.some(x => x.code === 'SILENT_ASSUMPTION')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// buildIntent
// ---------------------------------------------------------------------------

describe('ResearchCompiler.buildIntent', () => {
  it('builds a valid intent with generated intentId', () => {
    const result = compiler.buildIntent(validIntent());
    expect(Array.isArray(result)).toBe(false);
    if (!Array.isArray(result)) {
      expect(result.intentId).toMatch(/^intent_/);
      expect(result.keywords).toContain('caffeine');
    }
  });

  it('preserves provided intentId', () => {
    const result = compiler.buildIntent(validIntent({ intentId: 'intent_custom_42' }));
    if (!Array.isArray(result)) {
      expect(result.intentId).toBe('intent_custom_42');
    }
  });

  it('returns violations array for invalid input', () => {
    const result = compiler.buildIntent({ problemStatement: '' });
    expect(Array.isArray(result)).toBe(true);
    expect((result as any[]).length).toBeGreaterThan(0);
  });
});

// ---------------------------------------------------------------------------
// validateHypothesis
// ---------------------------------------------------------------------------

describe('ResearchCompiler.validateHypothesis', () => {
  it('returns no violations for a valid hypothesis', () => {
    const v = compiler.validateHypothesis(validHypothesis());
    expect(v).toHaveLength(0);
  });

  it('rejects missing statement', () => {
    const v = compiler.validateHypothesis(validHypothesis('i1', { statement: '' }));
    expect(v.some(x => x.code === 'INVALID_HYPOTHESIS')).toBe(true);
  });

  it('rejects missing nullHypothesis', () => {
    const v = compiler.validateHypothesis(validHypothesis('i1', { nullHypothesis: '' }));
    expect(v.some(x => x.code === 'SILENT_ASSUMPTION')).toBe(true);
  });

  it('rejects empty metrics array', () => {
    const v = compiler.validateHypothesis(validHypothesis('i1', { metrics: [] }));
    expect(v.some(x => x.code === 'MISSING_METRIC')).toBe(true);
  });

  it('rejects metric with non-finite threshold', () => {
    const badMetric = validMetric({ threshold: NaN });
    const v = compiler.validateHypothesis(validHypothesis('i1', { metrics: [badMetric] }));
    expect(v.some(x => x.code === 'METRIC_INTEGRITY_BREACH')).toBe(true);
  });

  it('rejects metric with empty unit', () => {
    const badMetric = validMetric({ unit: '' });
    const v = compiler.validateHypothesis(validHypothesis('i1', { metrics: [badMetric] }));
    expect(v.some(x => x.code === 'INVALID_METRIC')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// compile
// ---------------------------------------------------------------------------

describe('ResearchCompiler.compile', () => {
  it('compiles a valid hypothesis from intent', () => {
    const intentResult = compiler.buildIntent(validIntent());
    expect(Array.isArray(intentResult)).toBe(false);
    const intent = intentResult as ResearchIntent;

    const result = compiler.compile(intent, validHypothesis(intent.intentId));
    expect(Array.isArray(result)).toBe(false);
    if (!Array.isArray(result)) {
      expect(result.intentId).toBe(intent.intentId);
      expect(result.hypothesisId).toMatch(/^hyp_/);
      expect(result.metrics).toHaveLength(1);
    }
  });

  it('returns violations when hypothesis is malformed', () => {
    const intentResult = compiler.buildIntent(validIntent()) as ResearchIntent;
    const result = compiler.compile(intentResult, { statement: '', nullHypothesis: '' });
    expect(Array.isArray(result)).toBe(true);
    expect((result as any[]).length).toBeGreaterThan(0);
  });
});
