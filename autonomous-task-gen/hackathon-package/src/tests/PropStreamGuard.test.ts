/**
 * PropStreamGuard.test.ts – Phase 19: Guard-2 Unit Tests
 *
 * Verifies that PropStreamGuard correctly enforces PropStreamContract limits
 * and produces accurate PropStreamCheckpoints on violation.
 */

import { describe, it, expect, beforeEach } from "vitest";
import { PropStreamGuard } from "../guards/PropStreamGuard";
import type { PropStreamContract, PropStreamChunk } from "../types/constitution";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeChunk(data: Record<string, unknown>, seq = 0): PropStreamChunk {
  const serialised = JSON.stringify(data);
  return {
    data,
    byteLength: new TextEncoder().encode(serialised).length,
    seq,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("PropStreamGuard", () => {
  let guard: PropStreamGuard;
  const defaultContract: PropStreamContract = {
    maxNodes: 5,
    maxDepth: 3,
    maxPayloadBytes: 512,
    degradePolicy: "SOFT_SUMMARY",
  };

  beforeEach(() => {
    guard = new PropStreamGuard(defaultContract);
  });

  // -----------------------------------------------------------------------

  describe("safe stream", () => {
    it("returns SAFE for a small, shallow chunk", () => {
      const result = guard.validate(makeChunk({ type: "paragraph", text: "Hello" }));
      expect(result.status).toBe("SAFE");
      expect(result.checkpoint).toBeUndefined();
    });

    it("accumulates nodes across multiple safe chunks", () => {
      guard.validate(makeChunk({ a: 1 })); // 1 node
      guard.validate(makeChunk({ b: 2 })); // 1 node
      expect(guard.metrics.totalNodes).toBe(2);
    });
  });

  // -----------------------------------------------------------------------

  describe("node limit violation", () => {
    it("returns VIOLATION when total node count exceeds maxNodes", () => {
      // Each chunk below has > 1 node because of nested objects
      const contract: PropStreamContract = { ...defaultContract, maxNodes: 3 };
      guard = new PropStreamGuard(contract);

      guard.validate(makeChunk({ a: { b: 1 }, c: 2 }, 0)); // 3 nodes: root, a, c (a.b is primitive)
      const result = guard.validate(makeChunk({ d: { e: 3 } }, 1)); // pushes total > 3
      expect(result.status).toBe("VIOLATION");
    });

    it("attaches a checkpoint with the correct degrade policy", () => {
      const contract: PropStreamContract = { ...defaultContract, maxNodes: 1 };
      guard = new PropStreamGuard(contract);

      const result = guard.validate(makeChunk({ x: { y: 1 } }));
      expect(result.status).toBe("VIOLATION");
      expect(result.checkpoint).toBeDefined();
      expect(result.checkpoint!.degradePolicy).toBe("SOFT_SUMMARY");
    });

    it("remaining budget nodes is never negative", () => {
      // maxNodes: 1 → first nested object already pushes total to 2 (root + child)
      const contract: PropStreamContract = { ...defaultContract, maxNodes: 1 };
      guard = new PropStreamGuard(contract);

      const result = guard.validate(makeChunk({ a: { b: { c: { d: 1 } } } }));
      expect(result.status).toBe("VIOLATION");
      expect(result.checkpoint!.remainingBudget.nodes).toBeGreaterThanOrEqual(0);
    });
  });

  // -----------------------------------------------------------------------

  describe("payload size violation", () => {
    it("returns VIOLATION when cumulative byte size exceeds maxPayloadBytes", () => {
      const contract: PropStreamContract = { ...defaultContract, maxPayloadBytes: 10 };
      guard = new PropStreamGuard(contract);

      // First chunk is fine (< 10 bytes)
      guard.validate(makeChunk({ a: 1 }, 0));
      // Second chunk pushes cumulative over 10 bytes
      const result = guard.validate(makeChunk({ b: "long enough string" }, 1));
      expect(result.status).toBe("VIOLATION");
    });
  });

  // -----------------------------------------------------------------------

  describe("reset", () => {
    it("clears all accumulated metrics", () => {
      guard.validate(makeChunk({ x: { y: { z: 1 } } }));
      guard.reset();
      expect(guard.metrics.totalNodes).toBe(0);
      expect(guard.metrics.totalPayloadBytes).toBe(0);
      expect(guard.metrics.maxObservedDepth).toBe(0);
    });

    it("returns SAFE after reset even for previously violating data", () => {
      const contract: PropStreamContract = { ...defaultContract, maxNodes: 2 };
      guard = new PropStreamGuard(contract);

      // Trigger violation
      guard.validate(makeChunk({ a: 1, b: 2, c: 3 }));
      guard.reset();

      // Same chunk should pass after reset (still within limit on fresh start)
      const result = guard.validate(makeChunk({ a: 1 }));
      expect(result.status).toBe("SAFE");
    });
  });

  // -----------------------------------------------------------------------

  describe("checkpoint timestamp", () => {
    it("records an ISO-8601 timestamp on violation", () => {
      const contract: PropStreamContract = { ...defaultContract, maxNodes: 1 };
      guard = new PropStreamGuard(contract);

      const result = guard.validate(makeChunk({ a: { b: 1 } }));
      expect(result.checkpoint).toBeDefined();
      expect(() => new Date(result.checkpoint!.timestamp)).not.toThrow();
      expect(new Date(result.checkpoint!.timestamp).toISOString()).toBe(
        result.checkpoint!.timestamp,
      );
    });
  });
});
