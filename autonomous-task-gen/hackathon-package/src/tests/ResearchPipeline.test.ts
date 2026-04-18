/**
 * ResearchPipeline.test.ts – Integration tests for the full RGO 5-layer pipeline
 */

import { describe, expect, it } from 'vitest';
import { ResearchPipeline } from '../services/ResearchPipeline';
import type {
  ResearchIntent,
  FormalizedHypothesis,
  ExperimentSpec,
  ExperimentResult,
  ResearchMetric,
} from '../types/rgo';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function validIntentInput(): Partial<ResearchIntent> {
  return {
    problemStatement: 'Does aerobic exercise improve working memory in adults aged 40-60?',
    importance: 'Working memory decline is a key early marker of cognitive aging.',
    keywords: ['exercise', 'memory', 'aging', 'cognition'],
  };
}

function singleMetric(): ResearchMetric {
  return {
    metricId: 'wm_score',
    name: 'Working Memory Score',
    unit: 'points',
    operator: 'GTE',
    threshold: 80,
    isReproducibilityMetric: true,
  };
}

function validHypothesisInput(intentId: string): Partial<FormalizedHypothesis> {
  return {
    statement: 'Aerobic exercise (30 min/day, 8 weeks) improves working memory score by ≥10%.',
    nullHypothesis: 'Aerobic exercise has no significant effect on working memory score.',
    metrics: [singleMetric()],
    constraints: ['RCT design', 'age range 40-60', 'no prior neurological conditions'],
    intentId,
  };
}

function validSpec(hypothesisId: string): ExperimentSpec {
  return {
    experimentId: 'exp_wm_001',
    hypothesisId,
    procedure: ['Enroll 200 participants', 'Randomise to exercise/control', 'Measure at 0 and 8 weeks'],
    dataRequirements: ['wm_scores.csv'],
    expectedResults: { wm_score: 85 },
    randomSeed: 12345,
  };
}

function validResult(): ExperimentResult {
  return {
    experimentId: 'exp_wm_001',
    observedValues: { wm_score: 88 },
    executedAt: '2026-03-01T09:00:00.000Z',
    reproducibilityHash: 'rep_exp_wm_001_seed12345',
  };
}

// ---------------------------------------------------------------------------
// Happy-path: full pipeline
// ---------------------------------------------------------------------------

describe('ResearchPipeline – happy path', () => {
  it('advances through all phases and reaches COMPLETED', () => {
    const pipeline = new ResearchPipeline();

    // Phase ①: Intent
    const s1 = pipeline.submitIntent(validIntentInput());
    expect(s1.currentPhase).toBe('FORMALIZATION');
    expect(s1.status).toBe('IN_PROGRESS');
    expect(s1.intent).toBeDefined();
    expect(s1.ledgerEntries).toHaveLength(1);
    expect(s1.ledgerEntries[0].phase).toBe('INTENT');

    // Phase ②: Formalization
    const s2 = pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));
    expect(s2.currentPhase).toBe('GOVERNANCE_GATE_1');
    expect(s2.hypothesis).toBeDefined();
    expect(s2.ledgerEntries).toHaveLength(2);

    // Phase ③-⑤: Experiment + Gates + Ledger
    const s3 = pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      validResult()
    );
    expect(s3.status).toBe('COMPLETED');
    expect(s3.currentPhase).toBe('PAPER');
    expect(s3.gateResults).toHaveLength(2);
    expect(s3.gateResults[0].kind).toBe('PRE_EXECUTION');
    expect(s3.gateResults[1].kind).toBe('POST_EXECUTION');
    expect(s3.gateResults.every(g => g.status === 'PASS')).toBe(true);
  });

  it('ledger chain passes integrity verification after full pipeline', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s2 = pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));
    pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      validResult()
    );
    expect(pipeline.verifyLedgerIntegrity()).toBe(true);
  });

  it('renders a non-empty Markdown paper for a COMPLETED research project', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s2 = pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));
    pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      validResult()
    );

    const paper = pipeline.renderPaper(s1.researchId);
    expect(paper).toContain('# Research Paper');
    expect(paper).toContain('## Abstract');
    expect(paper).toContain('## Hypothesis');
    expect(paper).toContain('## Results');
    expect(paper).toContain('## Ledger');
    expect(paper).toContain('rep_exp_wm_001_seed12345');
  });
});

// ---------------------------------------------------------------------------
// Fail-Closed: intent validation
// ---------------------------------------------------------------------------

describe('ResearchPipeline – Fail-Closed intent', () => {
  it('throws when problemStatement is empty', () => {
    const pipeline = new ResearchPipeline();
    expect(() => pipeline.submitIntent({ problemStatement: '' })).toThrow(/INVALID_HYPOTHESIS/);
  });

  it('throws when importance is missing', () => {
    const pipeline = new ResearchPipeline();
    expect(() =>
      pipeline.submitIntent({
        problemStatement: 'A valid long enough problem statement here',
        keywords: ['k1'],
      })
    ).toThrow(/SILENT_ASSUMPTION/);
  });
});

// ---------------------------------------------------------------------------
// Fail-Closed: hypothesis formalization
// ---------------------------------------------------------------------------

describe('ResearchPipeline – Fail-Closed formalization', () => {
  it('throws when hypothesis has no metrics', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());

    expect(() =>
      pipeline.formalize(s1.researchId, {
        statement: 'Some hypothesis',
        nullHypothesis: 'The null',
        metrics: [],
        intentId: s1.intent!.intentId,
      })
    ).toThrow(/MISSING_METRIC/);
  });

  it('throws when called in the wrong phase', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    // Formalize once
    pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));
    // Calling again should throw (wrong phase)
    expect(() =>
      pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId))
    ).toThrow();
  });
});

// ---------------------------------------------------------------------------
// Fail-Closed: governance gate blocks execution
// ---------------------------------------------------------------------------

describe('ResearchPipeline – Fail-Closed governance gate', () => {
  it('blocks research when Gate① fails (no reproducibility metric)', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());

    const badMetric: ResearchMetric = {
      ...singleMetric(),
      isReproducibilityMetric: false,
    };
    const s2 = pipeline.formalize(s1.researchId, {
      ...validHypothesisInput(s1.intent!.intentId),
      metrics: [badMetric],
    });

    const s3 = pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      validResult()
    );

    expect(s3.status).toBe('BLOCKED');
    expect(s3.gateResults[0].status).toBe('FAIL');
    expect(s3.gateResults[0].violations.some(v => v.code === 'REPRODUCIBILITY_FAILED')).toBe(true);
  });

  it('blocks research when Gate② fails (missing reproducibility hash)', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s2 = pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));

    const s3 = pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      { ...validResult(), reproducibilityHash: '' }
    );

    expect(s3.status).toBe('BLOCKED');
    expect(s3.gateResults[1].kind).toBe('POST_EXECUTION');
    expect(s3.gateResults[1].violations.some(v => v.code === 'REPRODUCIBILITY_FAILED')).toBe(true);
  });

  it('throws when renderPaper is called on a BLOCKED research project', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s2 = pipeline.formalize(s1.researchId, validHypothesisInput(s1.intent!.intentId));

    // Cause Gate② failure
    pipeline.submitExperiment(
      s1.researchId,
      validSpec(s2.hypothesis!.hypothesisId),
      { ...validResult(), reproducibilityHash: '' }
    );

    expect(() => pipeline.renderPaper(s1.researchId)).toThrow(/BLOCKED/);
  });
});

// ---------------------------------------------------------------------------
// State inspection
// ---------------------------------------------------------------------------

describe('ResearchPipeline – state inspection', () => {
  it('getState() returns the current state', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s = pipeline.getState(s1.researchId);
    expect(s.researchId).toBe(s1.researchId);
    expect(s.currentPhase).toBe('FORMALIZATION');
  });

  it('getState() throws for unknown researchId', () => {
    const pipeline = new ResearchPipeline();
    expect(() => pipeline.getState('unknown_id')).toThrow(/not found/);
  });

  it('listResearchIds() returns all research IDs', () => {
    const pipeline = new ResearchPipeline();
    const s1 = pipeline.submitIntent(validIntentInput());
    const s2 = pipeline.submitIntent(validIntentInput());
    const ids = pipeline.listResearchIds();
    expect(ids).toContain(s1.researchId);
    expect(ids).toContain(s2.researchId);
  });
});
