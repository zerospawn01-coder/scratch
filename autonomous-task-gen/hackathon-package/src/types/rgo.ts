/**
 * rgo.ts – Research Governance OS (RGO): Type Definitions
 *
 * Defines the strict contracts for the 5-layer Research Governance OS:
 *   ① Intent Layer      – structured research intent
 *   ② Formalization Layer – hypothesis, metrics, causal constraints
 *   ③ Execution Layer   – experiment specification and results
 *   ④ Governance Layer  – Fail-Closed gate results and violations
 *   ⑤ Ledger Layer      – hash-chained immutable audit trail
 *
 * Design principles:
 *   - Fail-Closed: research cannot proceed unless conditions are met
 *   - No Silent Assumption: all premises must be explicit
 *   - Reproducibility First: non-reproducible results are rejected
 *   - Metric Integrity: a broken evaluation metric halts the pipeline
 */

// ---------------------------------------------------------------------------
// ① Intent Layer
// ---------------------------------------------------------------------------

/**
 * A fully-structured research intent. Raw natural language is prohibited;
 * every field must be supplied explicitly before the pipeline can advance.
 */
export interface ResearchIntent {
  /** Unique identifier for this intent record. */
  readonly intentId: string;
  /** Precise problem statement (no ambiguous natural language). */
  readonly problemStatement: string;
  /** Why this research matters (must not be empty). */
  readonly importance: string;
  /** Domain keywords used for governance cross-checking. */
  readonly keywords: readonly string[];
  /** ISO-8601 creation timestamp. */
  readonly createdAt: string;
}

// ---------------------------------------------------------------------------
// ② Formalization Layer
// ---------------------------------------------------------------------------

/**
 * A single measurable research metric.  Every metric must declare its
 * evaluation operator so that Governance Gate can verify integrity.
 */
export interface ResearchMetric {
  readonly metricId: string;
  readonly name: string;
  readonly unit: string;
  readonly operator: 'GT' | 'LT' | 'EQ' | 'GTE' | 'LTE';
  readonly threshold: number;
  /** When true, a failed reproducibility run on this metric halts execution. */
  readonly isReproducibilityMetric: boolean;
}

/**
 * A formally stated research hypothesis including its null form,
 * measurable metrics, explicit constraints, and an optional causal model.
 * Corresponds to "Causal Gating" in the RGO design.
 */
export interface FormalizedHypothesis {
  readonly hypothesisId: string;
  readonly intentId: string;
  /** Positive (alternative) hypothesis. */
  readonly statement: string;
  /** Null hypothesis (must be non-empty). */
  readonly nullHypothesis: string;
  /** At least one metric is required; empty list fails Governance Gate①. */
  readonly metrics: readonly ResearchMetric[];
  /** Explicit constraints – replaces any implicit assumptions. */
  readonly constraints: readonly string[];
  /**
   * Optional causal model expression, e.g., "X → Y via Z, not confounded by W".
   * Enforces the Causal Gating principle.
   */
  readonly causalModel?: string;
}

// ---------------------------------------------------------------------------
// ③ Execution Layer
// ---------------------------------------------------------------------------

/**
 * Specification for a reproducible experiment.
 * A random seed MUST be provided for any stochastic procedure.
 */
export interface ExperimentSpec {
  readonly experimentId: string;
  readonly hypothesisId: string;
  readonly procedure: readonly string[];
  readonly dataRequirements: readonly string[];
  /** Baseline expected values keyed by metric ID – used for drift detection. */
  readonly expectedResults: Record<string, number>;
  /** Required for reproducibility; pipeline blocks if omitted on stochastic runs. */
  readonly randomSeed?: number;
}

/**
 * Observed outcomes from a completed experiment execution.
 * The reproducibility hash is a content-hash of (experimentId + observedValues + randomSeed)
 * so that re-running the same spec produces the same hash.
 */
export interface ExperimentResult {
  readonly experimentId: string;
  /** Observed metric values keyed by metric ID. */
  readonly observedValues: Record<string, number>;
  readonly executedAt: string;
  /** Content-hash that allows deterministic re-execution verification. */
  readonly reproducibilityHash: string;
}

// ---------------------------------------------------------------------------
// ④ Governance Layer
// ---------------------------------------------------------------------------

/** Identifies which pipeline gate produced the result. */
export type GovernanceGateKind = 'PRE_EXECUTION' | 'POST_EXECUTION';

/** Machine-readable violation codes emitted by Governance Gates. */
export type GovernanceViolationCode =
  | 'INVALID_HYPOTHESIS'
  | 'MISSING_METRIC'
  | 'INVALID_METRIC'
  | 'DATA_LEAK_DETECTED'
  | 'P_HACKING_RISK'
  | 'REPRODUCIBILITY_FAILED'
  | 'METRIC_INTEGRITY_BREACH'
  | 'SILENT_ASSUMPTION';

export interface GovernanceViolation {
  readonly code: GovernanceViolationCode;
  readonly message: string;
  /** JSON path inside the offending data structure, if applicable. */
  readonly path?: string;
}

/** PASS = gate cleared; FAIL = pipeline must halt (Fail-Closed). */
export type GovernanceGateStatus = 'PASS' | 'FAIL';

export interface GovernanceGateResult {
  readonly gateId: string;
  readonly kind: GovernanceGateKind;
  readonly status: GovernanceGateStatus;
  /** Empty array on PASS; one or more violations on FAIL. */
  readonly violations: readonly GovernanceViolation[];
  readonly evaluatedAt: string;
}

// ---------------------------------------------------------------------------
// ⑤ Ledger Layer
// ---------------------------------------------------------------------------

/**
 * An immutable, hash-chained entry in the Research Ledger.
 * The chain starts with previousHash = "GENESIS".
 * Papers are generated as views over the ledger – they are not stored separately.
 */
export interface LedgerEntry {
  readonly ledgerSequence: number;
  readonly researchId: string;
  readonly phase: ResearchPhase;
  readonly payload: Record<string, unknown>;
  /** Hash of the previous entry (or "GENESIS" for the first entry). */
  readonly previousHash: string;
  /** Deterministic hash of this entry's content. */
  readonly entryHash: string;
  readonly committedAt: string;
}

// ---------------------------------------------------------------------------
// Pipeline orchestration types
// ---------------------------------------------------------------------------

/**
 * Ordered phases of the RGO pipeline.
 * The pipeline advances linearly; skipping or reordering is prohibited.
 */
export type ResearchPhase =
  | 'INTENT'
  | 'FORMALIZATION'
  | 'GOVERNANCE_GATE_1'
  | 'EXECUTION'
  | 'GOVERNANCE_GATE_2'
  | 'LEDGER'
  | 'PAPER';

export type ResearchStatus =
  | 'IN_PROGRESS'
  | 'BLOCKED'
  | 'COMPLETED'
  | 'FAILED';

/**
 * Full mutable state of one research project as it flows through the pipeline.
 */
export interface ResearchState {
  readonly researchId: string;
  readonly currentPhase: ResearchPhase;
  readonly status: ResearchStatus;
  readonly intent?: ResearchIntent;
  readonly hypothesis?: FormalizedHypothesis;
  readonly experimentSpec?: ExperimentSpec;
  readonly experimentResult?: ExperimentResult;
  /** Ordered list of all governance gate evaluations. */
  readonly gateResults: readonly GovernanceGateResult[];
  /** Ordered list of all ledger entries for this research. */
  readonly ledgerEntries: readonly LedgerEntry[];
  readonly startedAt: string;
  readonly updatedAt: string;
}
