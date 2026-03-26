/**
 * ResearchLedger.ts – RGO ⑤: Ledger Layer
 *
 * An append-only, hash-chained ledger of all research pipeline events.
 * Every decision, gate result, and experiment outcome is recorded here.
 *
 * Properties:
 *   - Immutable entries (append-only)
 *   - Hash chain: each entry includes the hash of the previous entry
 *   - Tamper-evident: verifyIntegrity() re-computes and checks every link
 *   - Papers are views over the ledger, not independent documents
 *
 * Hash algorithm: deterministic FNV-1a (same family as AuthorizationWal)
 * so the ledger remains dependency-free and works in all JS runtimes.
 */

import type { LedgerEntry, ResearchPhase } from '../types/rgo';

function stableStringify(value: Record<string, unknown>): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  const sortedKeys = Object.keys(value).sort();
  const sorted: Record<string, unknown> = {};
  for (const key of sortedKeys) {
    sorted[key] = value[key];
  }
  return JSON.stringify(sorted);
}

/**
 * Deterministic FNV-1a 32-bit hash (dependency-free, tamper-evident).
 * Prefixed with "ledger_" to distinguish from WAL hashes.
 */
function hashString(input: string): string {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return `ledger_${(h >>> 0).toString(16).padStart(8, '0')}`;
}

export class ResearchLedger {
  private entries: LedgerEntry[] = [];
  private sequence = 0;

  /**
   * Append a new entry to the ledger.
   * The entry hash incorporates the previous hash to form the chain.
   */
  append(
    researchId: string,
    phase: ResearchPhase,
    payload: Record<string, unknown>
  ): LedgerEntry {
    const previousHash =
      this.entries.length > 0
        ? this.entries[this.entries.length - 1].entryHash
        : 'GENESIS';
    const ledgerSequence = this.sequence + 1;
    const committedAt = new Date().toISOString();

    const hashBase = stableStringify({
      previousHash,
      ledgerSequence,
      researchId,
      phase,
      payload,
    });

    const entry: LedgerEntry = {
      ledgerSequence,
      researchId,
      phase,
      payload,
      previousHash,
      entryHash: hashString(hashBase),
      committedAt,
    };

    this.entries.push(entry);
    this.sequence = ledgerSequence;
    return entry;
  }

  /**
   * Return all entries in insertion order (oldest-first).
   */
  list(): LedgerEntry[] {
    return [...this.entries];
  }

  /**
   * Return entries for a specific research project.
   */
  listByResearch(researchId: string): LedgerEntry[] {
    return this.entries.filter(e => e.researchId === researchId);
  }

  /**
   * Verify the integrity of the entire hash chain.
   * Returns true if every entry's hash is correctly derived from the previous one.
   * Returns false if any link is broken (indicates tampering).
   */
  verifyIntegrity(): boolean {
    for (let i = 0; i < this.entries.length; i++) {
      const entry = this.entries[i];
      const expectedPrevious = i === 0 ? 'GENESIS' : this.entries[i - 1].entryHash;

      if (entry.previousHash !== expectedPrevious) {
        return false;
      }

      const hashBase = stableStringify({
        previousHash: entry.previousHash,
        ledgerSequence: entry.ledgerSequence,
        researchId: entry.researchId,
        phase: entry.phase,
        payload: entry.payload,
      });

      if (hashString(hashBase) !== entry.entryHash) {
        return false;
      }
    }
    return true;
  }

  /**
   * Total number of entries across all research projects.
   */
  get size(): number {
    return this.entries.length;
  }

  /**
   * Clear the ledger (only for testing / reset scenarios).
   */
  clear(): void {
    this.entries = [];
    this.sequence = 0;
  }
}
