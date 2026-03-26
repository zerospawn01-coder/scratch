import type { 
  NomosMutation, 
  AuditAtom 
} from '../types/constitution';
import type { 
  MutationDecision, 
  PlaybookContext
} from '../types/governance';
import { AuthorizationWal } from './AuthorizationWal';
import { PropStreamTelemetryEngine } from './PropStreamTelemetryEngine';

export interface PlaybookOutcome {
  readonly mutationId: string;
  readonly decision: MutationDecision;
  readonly atom: AuditAtom;
}

export class PlaybookRunner {
  private activeTimeouts: Map<string, any> = new Map();

  constructor(
    private wal: AuthorizationWal,
    private telemetry: PropStreamTelemetryEngine
  ) {}

  /**
   * Starts a playbook for a mutation with a fixed timeout.
   */
  startMutation(
    mutation: NomosMutation, 
    timeoutMs: number, 
    onTimeout: (outcome: PlaybookOutcome) => void
  ): PlaybookContext {
    const context: PlaybookContext = {
      runId: `pb_run_${Date.now()}`,
      mutationId: mutation.mutationId,
      timeoutMs,
      startedAt: new Date().toISOString()
    };

    const timer = setTimeout(() => {
      const outcome = this.handleDecision(mutation, 'TIMEOUT_REJECT');
      onTimeout(outcome);
    }, timeoutMs);

    this.activeTimeouts.set(mutation.mutationId, timer);
    return context;
  }

  /**
   * Records a manual or timeout-based decision and ensures Audit Write Synergy.
   */
  handleDecision(
    mutation: NomosMutation, 
    decision: MutationDecision
  ): PlaybookOutcome {
    // Clear any pending timeout
    const timer = this.activeTimeouts.get(mutation.mutationId);
    if (timer) {
      clearTimeout(timer);
      this.activeTimeouts.delete(mutation.mutationId);
    }

    const outcomeLabel: "MUTATION_APPROVED" | "MUTATION_REJECTED" = 
      decision === 'APPROVE' ? "MUTATION_APPROVED" : "MUTATION_REJECTED";

    try {
      // 1. Write to WAL (Base Contract)
      const atom = this.wal.appendMutation(mutation, outcomeLabel);

      // 2. Transmit to Telemetry (Audit Trace)
      this.telemetry.recordWalAudit(atom);

      // Success Path
      return {
        mutationId: mutation.mutationId,
        decision,
        atom
      };
    } catch (err) {
      // FM-3: Audit Write Synergy Violation (Fail-closed)
      console.error("[SINCERE] CRITICAL: Audit write failure during mutation decision.", err);
      throw new Error("AUDIT_WRITE_FAILURE: System must halt. Operational integrity compromised.");
    }
  }

  public clear(): void {
    this.activeTimeouts.forEach(t => clearTimeout(t));
    this.activeTimeouts.clear();
  }
}
