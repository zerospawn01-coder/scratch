/**
 * governance.ts – Phase 34: Hardened Governance Vocabulary & Types
 * 
 * Defines the strict contracts for SLO evaluation, alerting policies,
 * and HITL decision making.
 */

export type ConstraintKind = 'SLO' | 'POLICY';

export type SloSeverity = 'WARNING' | 'CRITICAL' | 'FATAL';

export type EvaluationDisposition =
  | 'ALLOW'
  | 'DEDUPE'
  | 'ESCALATE'
  | 'REJECT'
  | 'BLOCK';

export type AuditWriteStatus = 'SUCCEEDED' | 'FAILED';

export type MutationDecision = 'APPROVE' | 'REJECT' | 'TIMEOUT_REJECT';

export type MetricUnit = 'ms' | 'count' | 'bool' | 'status' | 'bytes';

export interface SloThresholdBand {
  warning?: number;
  critical: number;
  fatal?: number;
}

export interface SloConfiguration {
  readonly sloId: string;
  readonly kind: ConstraintKind;
  readonly threshold: Readonly<{
    operator: 'GT' | 'LT' | 'EQ';
    value: number;
    unit: MetricUnit;
  }>;
  readonly bands?: SloThresholdBand;
}

export interface SloEvaluationResult {
  readonly sloId: string;
  readonly disposition: EvaluationDisposition;
  readonly severity?: SloSeverity;
  readonly observedValue: number;
  readonly breachDistance: number;
  readonly timestamp: string;
}

export interface PolicyConfiguration {
  readonly policyId: string;
  readonly kind: 'POLICY';
  readonly cooldownMs: number;
  readonly dedupeKeySurface: readonly string[]; // Fixed set of fields for hashing
}

export interface PolicyEvaluationResult {
  readonly policyId: string;
  readonly disposition: EvaluationDisposition;
  readonly reason?: string;
  readonly snapshotHash: string; // Deterministic hash of the trigger surface
  readonly timestamp: string;
}

export interface PlaybookContext {
  readonly runId: string;
  readonly mutationId: string;
  readonly timeoutMs: number;
  readonly startedAt: string;
}

export interface GovernanceAuditRecord {
  readonly type: 'SLO_BREACH' | 'POLICY_VIOLATION' | 'MUTATION_DECISION';
  readonly payload: Record<string, unknown>;
  readonly writeStatus: AuditWriteStatus;
  readonly checksum: string;
}
