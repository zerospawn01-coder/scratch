import type { AuditAtom, AuditOutcome, DegradePolicy, NomosMutation } from "../types/constitution";

interface AppendAuditInput {
  runId: string;
  streamMode: "safe" | "stress";
  outcome: AuditOutcome;
  violatingPath?: string;
  degradePolicy?: DegradePolicy;
}

function normalizeForHash(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(normalizeForHash);
  }
  if (value && typeof value === "object") {
    return Object.keys(value as Record<string, unknown>)
      .sort()
      .reduce<Record<string, unknown>>((acc, key) => {
        acc[key] = normalizeForHash((value as Record<string, unknown>)[key]);
        return acc;
      }, {});
  }
  return value;
}

function stableStringify(value: Record<string, unknown>): string {
  return JSON.stringify(normalizeForHash(value));
}

// Simple deterministic hash for audit chaining without runtime crypto dependencies.
function hashString(input: string): string {
  let h1 = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    h1 ^= input.charCodeAt(i);
    h1 = Math.imul(h1, 0x01000193);
  }
  return `wal_${(h1 >>> 0).toString(16).padStart(8, "0")}`;
}

export class AuthorizationWal {
  private atoms: AuditAtom[] = [];
  private logicalSequence = 0;

  appendAtomic(input: AppendAuditInput): AuditAtom {
    const timestamp = new Date().toISOString();
    const previousHash = this.atoms.length > 0 ? this.atoms[this.atoms.length - 1].walCommitHash : "GENESIS";
    const walSequence = this.logicalSequence + 1;

    const hashBase = stableStringify({
      previousHash,
      walSequence,
      runId: input.runId,
      streamMode: input.streamMode,
      outcome: input.outcome,
      violatingPath: input.violatingPath ?? "",
      degradePolicy: input.degradePolicy ?? "",
    });

    const atom: AuditAtom = {
      walSequence,
      runId: input.runId,
      streamMode: input.streamMode,
      outcome: input.outcome,
      violatingPath: input.violatingPath,
      degradePolicy: input.degradePolicy,
      timestamp,
      walCommitHash: hashString(hashBase),
    };

    this.atoms.push(atom);
    this.logicalSequence = walSequence;
    return atom;
  }

  /**
   * Record a structural mutation decision (Phase 33).
   */
  appendMutation(mutation: NomosMutation, outcome: "MUTATION_APPROVED" | "MUTATION_REJECTED"): AuditAtom {
    const timestamp = new Date().toISOString();
    const previousHash = this.atoms.length > 0 ? this.atoms[this.atoms.length - 1].walCommitHash : "GENESIS";
    const walSequence = this.logicalSequence + 1;
    const immutablePayload = normalizeForHash(mutation.payload ?? {}) as Record<string, unknown>;

    const hashBase = stableStringify({
      previousHash,
      walSequence,
      mutationId: mutation.mutationId,
      target: mutation.target,
      action: mutation.action,
      outcome,
      payload: immutablePayload,
    });

    const atom: AuditAtom = {
      walSequence,
      runId: `mutation_${mutation.mutationId}`,
      streamMode: "safe", // Mutations are administrative
      outcome,
      violatingPath: mutation.target,
      timestamp,
      walCommitHash: hashString(hashBase),
      mutationPayload: immutablePayload,
    };

    this.atoms.push(atom);
    this.logicalSequence = walSequence;
    return atom;
  }

  list(): AuditAtom[] {
    return [...this.atoms];
  }

  clear(): void {
    this.atoms = [];
    this.logicalSequence = 0;
  }
}
