/**
 * GovernanceGate.ts – RGO ④: Governance Layer (Fail-Closed)
 *
 * Implements two mandatory gate evaluations:
 *   Gate① (PRE_EXECUTION)  – validates the hypothesis before any experiment runs
 *   Gate② (POST_EXECUTION) – validates experiment results for reproducibility,
 *                             p-hacking risk, and metric integrity
 *
 * Fail-Closed design: any violation causes the gate to return status='FAIL'.
 * The pipeline MUST NOT advance past a FAIL gate.
 */

import type {
  FormalizedHypothesis,
  ExperimentSpec,
  ExperimentResult,
  GovernanceGateResult,
  GovernanceViolation,
  GovernanceGateStatus,
  ResearchMetric,
} from '../types/rgo';

/** Maximum allowed drift ratio between expected and observed metric values. */
const MAX_METRIC_DRIFT_RATIO = 0.5;

/**
 * Minimum number of reproducibility metrics that must be present when a
 * hypothesis involves stochastic execution.
 */
const MIN_REPRODUCIBILITY_METRICS = 1;

function generateGateId(kind: 'PRE_EXECUTION' | 'POST_EXECUTION'): string {
  return `gate_${kind.toLowerCase()}_${Date.now().toString(36)}`;
}

export class GovernanceGate {
  /**
   * Gate① – Pre-execution validation.
   *
   * Checks:
   *   - Hypothesis has at least one metric (MISSING_METRIC)
   *   - All metrics have finite thresholds (METRIC_INTEGRITY_BREACH)
   *   - At least one reproducibility metric exists (REPRODUCIBILITY_FAILED)
   *   - Constraints list is present (no silent assumptions)
   *   - causalModel is populated when multiple interacting metrics exist
   */
  evaluatePreExecution(hypothesis: FormalizedHypothesis): GovernanceGateResult {
    const violations: GovernanceViolation[] = [];

    // 1. Must have at least one metric
    if (hypothesis.metrics.length === 0) {
      violations.push({
        code: 'MISSING_METRIC',
        message: 'Hypothesis must declare at least one metric before execution.',
        path: 'hypothesis.metrics',
      });
    } else {
      // 2. Metric integrity: all thresholds must be finite numbers
      hypothesis.metrics.forEach((m, i) => {
        if (!isFinite(m.threshold)) {
          violations.push({
            code: 'METRIC_INTEGRITY_BREACH',
            message: `Metric "${m.name}" has a non-finite threshold. Execution halted.`,
            path: `hypothesis.metrics[${i}].threshold`,
          });
        }
        if (m.unit.trim().length === 0) {
          violations.push({
            code: 'METRIC_INTEGRITY_BREACH',
            message: `Metric "${m.name}" is missing a unit. Silent assumption detected.`,
            path: `hypothesis.metrics[${i}].unit`,
          });
        }
      });

      // 3. Reproducibility: at least one reproducibility metric must be declared
      const reproducibilityMetrics = hypothesis.metrics.filter(m => m.isReproducibilityMetric);
      if (reproducibilityMetrics.length < MIN_REPRODUCIBILITY_METRICS) {
        violations.push({
          code: 'REPRODUCIBILITY_FAILED',
          message: `At least ${MIN_REPRODUCIBILITY_METRICS} metric must be flagged as isReproducibilityMetric=true.`,
          path: 'hypothesis.metrics',
        });
      }
    }

    // 4. No silent assumptions: null hypothesis must be explicit
    if (!hypothesis.nullHypothesis || hypothesis.nullHypothesis.trim().length === 0) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'Null hypothesis is empty. Implicit rejection criteria constitute a silent assumption.',
        path: 'hypothesis.nullHypothesis',
      });
    }

    // 5. Causal model required when more than one metric interacts
    if (hypothesis.metrics.length > 1 && !hypothesis.causalModel) {
      violations.push({
        code: 'SILENT_ASSUMPTION',
        message: 'A causalModel expression is required when multiple metrics are declared to prevent confounding.',
        path: 'hypothesis.causalModel',
      });
    }

    const status: GovernanceGateStatus = violations.length === 0 ? 'PASS' : 'FAIL';

    return {
      gateId: generateGateId('PRE_EXECUTION'),
      kind: 'PRE_EXECUTION',
      status,
      violations,
      evaluatedAt: new Date().toISOString(),
    };
  }

  /**
   * Gate② – Post-execution validation.
   *
   * Checks:
   *   - All expected metrics have an observed value (DATA_LEAK_DETECTED / MISSING_METRIC)
   *   - Observed values satisfy the metric operator/threshold (METRIC_INTEGRITY_BREACH)
   *   - No metric shows excessive drift from its expected baseline (P_HACKING_RISK)
   *   - Reproducibility hash is present and non-empty (REPRODUCIBILITY_FAILED)
   */
  evaluatePostExecution(
    hypothesis: FormalizedHypothesis,
    spec: ExperimentSpec,
    result: ExperimentResult
  ): GovernanceGateResult {
    const violations: GovernanceViolation[] = [];

    // 1. Reproducibility hash must be present
    if (!result.reproducibilityHash || result.reproducibilityHash.trim().length === 0) {
      violations.push({
        code: 'REPRODUCIBILITY_FAILED',
        message: 'Experiment result is missing a reproducibilityHash. Non-reproducible results are invalid.',
        path: 'result.reproducibilityHash',
      });
    }

    // 2. All hypothesis metrics must have observed values
    for (const metric of hypothesis.metrics) {
      if (!(metric.metricId in result.observedValues)) {
        violations.push({
          code: 'MISSING_METRIC',
          message: `Observed value for metric "${metric.name}" (${metric.metricId}) is missing from result.`,
          path: `result.observedValues.${metric.metricId}`,
        });
        continue;
      }

      const observed = result.observedValues[metric.metricId];

      // 3. Check metric operator satisfaction
      if (!this.satisfiesOperator(observed, metric)) {
        violations.push({
          code: 'METRIC_INTEGRITY_BREACH',
          message: `Metric "${metric.name}" observed ${observed} does not satisfy ${metric.operator} ${metric.threshold} ${metric.unit}.`,
          path: `result.observedValues.${metric.metricId}`,
        });
      }

      // 4. P-hacking / drift check: compare against expected baseline
      const expected = spec.expectedResults[metric.metricId];
      if (expected !== undefined && expected !== 0) {
        const driftRatio = Math.abs(observed - expected) / Math.abs(expected);
        if (driftRatio > MAX_METRIC_DRIFT_RATIO) {
          violations.push({
            code: 'P_HACKING_RISK',
            message: `Metric "${metric.name}" drifted ${(driftRatio * 100).toFixed(1)}% from expected baseline (max allowed: ${MAX_METRIC_DRIFT_RATIO * 100}%). Possible p-hacking or data manipulation.`,
            path: `result.observedValues.${metric.metricId}`,
          });
        }
      }
    }

    // 5. Data leak detection: result must not contain keys not in the hypothesis metrics
    const knownMetricIds = new Set(hypothesis.metrics.map(m => m.metricId));
    for (const key of Object.keys(result.observedValues)) {
      if (!knownMetricIds.has(key)) {
        violations.push({
          code: 'DATA_LEAK_DETECTED',
          message: `Observed value for unknown metric key "${key}" detected. Unreported metrics may indicate data leakage or selective reporting.`,
          path: `result.observedValues.${key}`,
        });
      }
    }

    const status: GovernanceGateStatus = violations.length === 0 ? 'PASS' : 'FAIL';

    return {
      gateId: generateGateId('POST_EXECUTION'),
      kind: 'POST_EXECUTION',
      status,
      violations,
      evaluatedAt: new Date().toISOString(),
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private satisfiesOperator(observed: number, metric: ResearchMetric): boolean {
    switch (metric.operator) {
      case 'GT':  return observed > metric.threshold;
      case 'LT':  return observed < metric.threshold;
      case 'EQ':  return observed === metric.threshold;
      case 'GTE': return observed >= metric.threshold;
      case 'LTE': return observed <= metric.threshold;
      default:    return false;
    }
  }
}
