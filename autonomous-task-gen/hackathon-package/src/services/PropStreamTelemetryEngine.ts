import type { AuditAtom, TelemetryAuditEvent } from "../types/constitution";

export class PropStreamTelemetryEngine {
  private events: TelemetryAuditEvent[] = [];

  recordWalAudit(atom: AuditAtom): TelemetryAuditEvent {
    const event: TelemetryAuditEvent = {
      walSequence: atom.walSequence,
      runId: atom.runId,
      streamMode: atom.streamMode,
      outcome: atom.outcome,
      walCommitHash: atom.walCommitHash,
      timestamp: atom.timestamp,
      violatingPath: atom.violatingPath,
      mutationPayload: atom.mutationPayload,
      rawAtom: atom,
    };

    this.events = [event, ...this.events];
    return event;
  }

  getEvents(limit = 20): TelemetryAuditEvent[] {
    return this.events.slice(0, limit);
  }

  clear(): void {
    this.events = [];
  }
}
