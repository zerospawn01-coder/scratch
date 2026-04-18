/**
 * ResearchCompiler.ts – RGO ① + ②: Intent Structuring & Formalization
 *
 * Validates a raw intent input and compiles it into a FormalizedHypothesis.
 * Raw natural language intent is rejected; all fields must be explicit.
 *
 * Returns either a validated FormalizedHypothesis or a list of GovernanceViolations
 * so the caller can surface actionable errors rather than silently failing.
 */

import type {
  ResearchIntent,
  FormalizedHypothesis,
  ResearchMetric,
  GovernanceViolation,
} from '../types/rgo';

/** Minimum word count for problem statements to prevent trivially vague descriptions. */
const MIN_PROBLEM_STATEMENT_WORDS = 5;

function generateId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

export class ResearchCompiler {
  /**
   * Validate a partial intent input. Returns an empty array on success,
   * or one or more GovernanceViolation records on failure.
   */
  validateIntent(input: Partial<ResearchIntent>): GovernanceViolation[] {
    const violations: GovernanceViolation[] = [];

    if (!input.problemStatement || input.problemStatement.trim().length === 0) {
      violations.push({
        code: 'INVALID_HYPOTHESIS',
        message: 'problemStatement is required and must not be empty.',
        path: 'intent.problemStatement',
      });
    } else if (input.problemStatement.trim().split(/\s+/).length < MIN_PROBLEM_STATEMENT_WORDS) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: `problemStatement must contain at least ${MIN_PROBLEM_STATEMENT_WORDS} words to prevent ambiguous intent.`,
        path: 'intent.problemStatement',
      });
    }

    if (!input.importance || input.importance.trim().length === 0) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'importance must be explicitly stated; implicit justification is not permitted.',
        path: 'intent.importance',
      });
    }

    if (!input.keywords || input.keywords.length === 0) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'At least one keyword is required for governance cross-checking.',
        path: 'intent.keywords',
      });
    }

    return violations;
  }

  /**
   * Build a fully-validated ResearchIntent from a partial input.
   * Throws (Fail-Closed) if the input is invalid.
   */
  buildIntent(input: Partial<ResearchIntent>): ResearchIntent | GovernanceViolation[] {
    const violations = this.validateIntent(input);
    if (violations.length > 0) {
      return violations;
    }

    return {
      intentId: input.intentId ?? generateId('intent'),
      problemStatement: input.problemStatement!.trim(),
      importance: input.importance!.trim(),
      keywords: input.keywords!,
      createdAt: input.createdAt ?? new Date().toISOString(),
    };
  }

  /**
   * Validate a FormalizedHypothesis. Returns empty array on success.
   */
  validateHypothesis(input: Partial<FormalizedHypothesis>): GovernanceViolation[] {
    const violations: GovernanceViolation[] = [];

    if (!input.statement || input.statement.trim().length === 0) {
      violations.push({
        code: 'INVALID_HYPOTHESIS',
        message: 'Hypothesis statement is required.',
        path: 'hypothesis.statement',
      });
    }

    if (!input.nullHypothesis || input.nullHypothesis.trim().length === 0) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'Null hypothesis must be explicitly stated; absence implies silent assumption.',
        path: 'hypothesis.nullHypothesis',
      });
    }

    if (!input.metrics || input.metrics.length === 0) {
      violations.push({
        code: 'MISSING_METRIC',
        message: 'At least one ResearchMetric is required for a falsifiable hypothesis.',
        path: 'hypothesis.metrics',
      });
    } else {
      input.metrics.forEach((m, i) => {
        const metricViolations = this.validateMetric(m, `hypothesis.metrics[${i}]`);
        violations.push(...metricViolations);
      });
    }

    if (!input.intentId || input.intentId.trim().length === 0) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'intentId must be linked to a valid ResearchIntent.',
        path: 'hypothesis.intentId',
      });
    }

    return violations;
  }

  /**
   * Compile a FormalizedHypothesis from a validated intent and partial hypothesis data.
   * Returns violations if the hypothesis is not well-formed.
   */
  compile(
    intent: ResearchIntent,
    hypothesisInput: Partial<FormalizedHypothesis>
  ): FormalizedHypothesis | GovernanceViolation[] {
    const input: Partial<FormalizedHypothesis> = {
      ...hypothesisInput,
      intentId: intent.intentId,
    };

    const violations = this.validateHypothesis(input);
    if (violations.length > 0) {
      return violations;
    }

    return {
      hypothesisId: input.hypothesisId ?? generateId('hyp'),
      intentId: intent.intentId,
      statement: input.statement!.trim(),
      nullHypothesis: input.nullHypothesis!.trim(),
      metrics: input.metrics!,
      constraints: input.constraints ?? [],
      causalModel: input.causalModel,
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private validateMetric(m: ResearchMetric, path: string): GovernanceViolation[] {
    const violations: GovernanceViolation[] = [];

    if (!m.metricId || m.metricId.trim().length === 0) {
      violations.push({ code: 'INVALID_METRIC', message: 'metricId is required.', path });
    }
    if (!m.name || m.name.trim().length === 0) {
      violations.push({ code: 'INVALID_METRIC', message: 'metric name is required.', path });
    }
    if (!m.unit || m.unit.trim().length === 0) {
      violations.push({ code: 'INVALID_METRIC', message: 'metric unit is required.', path });
    }
    if (!['GT', 'LT', 'EQ', 'GTE', 'LTE'].includes(m.operator)) {
      violations.push({
        code: 'INVALID_METRIC',
        message: `metric operator "${m.operator}" is not a valid comparator.`,
        path,
      });
    }
    if (typeof m.threshold !== 'number' || !isFinite(m.threshold)) {
      violations.push({
        code: 'METRIC_INTEGRITY_BREACH',
        message: 'metric threshold must be a finite number.',
        path,
      });
    }

    return violations;
  }
}
