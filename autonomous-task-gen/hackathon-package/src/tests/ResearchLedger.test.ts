/**
 * ResearchLedger.test.ts – Unit tests for RGO Ledger Layer
 */

import { describe, expect, it } from 'vitest';
import { ResearchLedger } from '../services/ResearchLedger';

describe('ResearchLedger', () => {
  it('appends the first entry with previousHash = GENESIS', () => {
    const ledger = new ResearchLedger();
    const entry = ledger.append('r1', 'INTENT', { note: 'first' });

    expect(entry.ledgerSequence).toBe(1);
    expect(entry.previousHash).toBe('GENESIS');
    expect(entry.entryHash).toMatch(/^ledger_[0-9a-f]{8}$/);
    expect(entry.researchId).toBe('r1');
    expect(entry.phase).toBe('INTENT');
  });

  it('chains subsequent entries correctly', () => {
    const ledger = new ResearchLedger();
    const e1 = ledger.append('r1', 'INTENT', {});
    const e2 = ledger.append('r1', 'FORMALIZATION', {});
    const e3 = ledger.append('r1', 'GOVERNANCE_GATE_1', {});

    expect(e2.previousHash).toBe(e1.entryHash);
    expect(e3.previousHash).toBe(e2.entryHash);
    expect(e2.ledgerSequence).toBe(2);
    expect(e3.ledgerSequence).toBe(3);
  });

  it('produces different hashes for different payloads', () => {
    const ledger = new ResearchLedger();
    const e1 = ledger.append('r1', 'INTENT', { value: 'a' });
    ledger.clear();
    const e2 = ledger.append('r1', 'INTENT', { value: 'b' });

    expect(e1.entryHash).not.toBe(e2.entryHash);
  });

  it('produces the same hash for identical first entries', () => {
    const ledgerA = new ResearchLedger();
    const eA = ledgerA.append('r1', 'INTENT', { key: 'same' });

    const ledgerB = new ResearchLedger();
    const eB = ledgerB.append('r1', 'INTENT', { key: 'same' });

    expect(eA.entryHash).toBe(eB.entryHash);
  });

  it('list() returns entries in insertion order', () => {
    const ledger = new ResearchLedger();
    ledger.append('r1', 'INTENT', {});
    ledger.append('r1', 'FORMALIZATION', {});
    ledger.append('r1', 'EXECUTION', {});

    const entries = ledger.list();
    expect(entries).toHaveLength(3);
    expect(entries[0].phase).toBe('INTENT');
    expect(entries[1].phase).toBe('FORMALIZATION');
    expect(entries[2].phase).toBe('EXECUTION');
  });

  it('listByResearch() filters by researchId', () => {
    const ledger = new ResearchLedger();
    ledger.append('r1', 'INTENT', {});
    ledger.append('r2', 'INTENT', {});
    ledger.append('r1', 'FORMALIZATION', {});

    const r1Entries = ledger.listByResearch('r1');
    expect(r1Entries).toHaveLength(2);
    expect(r1Entries.every(e => e.researchId === 'r1')).toBe(true);
  });

  it('verifyIntegrity() returns true for a valid chain', () => {
    const ledger = new ResearchLedger();
    ledger.append('r1', 'INTENT', { a: 1 });
    ledger.append('r1', 'FORMALIZATION', { b: 2 });
    ledger.append('r1', 'EXECUTION', { c: 3 });

    expect(ledger.verifyIntegrity()).toBe(true);
  });

  it('verifyIntegrity() returns true for empty ledger', () => {
    const ledger = new ResearchLedger();
    expect(ledger.verifyIntegrity()).toBe(true);
  });

  it('verifyIntegrity() returns false when an entry is tampered', () => {
    const ledger = new ResearchLedger();
    ledger.append('r1', 'INTENT', {});
    ledger.append('r1', 'FORMALIZATION', {});

    // Directly mutate a private entry to simulate tampering
    const entries = (ledger as any).entries as any[];
    entries[0].entryHash = 'tampered_hash';

    expect(ledger.verifyIntegrity()).toBe(false);
  });

  it('clear() resets the ledger', () => {
    const ledger = new ResearchLedger();
    ledger.append('r1', 'INTENT', {});
    ledger.clear();

    expect(ledger.size).toBe(0);

    const entry = ledger.append('r1', 'INTENT', {});
    expect(entry.ledgerSequence).toBe(1);
    expect(entry.previousHash).toBe('GENESIS');
  });

  it('size property reflects the number of entries', () => {
    const ledger = new ResearchLedger();
    expect(ledger.size).toBe(0);
    ledger.append('r1', 'INTENT', {});
    ledger.append('r1', 'FORMALIZATION', {});
    expect(ledger.size).toBe(2);
  });
});
