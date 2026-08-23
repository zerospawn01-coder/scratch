/**
 * PropStreamGuard.ts – Phase 19: Guard-2 Runtime Validator
 *
 * Guard-2 inspects every PropStreamChunk against the active PropStreamContract.
 * It counts DOM-equivalent nodes, measures nesting depth, and tracks cumulative
 * payload size. The moment any budget is exceeded it returns a VIOLATION with
 * a PropStreamCheckpoint that records the exact breach path.
 */

import type {
  PropStreamChunk,
  PropStreamContract,
  GuardResult,
  PropStreamCheckpoint,
} from "../types/constitution";

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Recursively counts the number of nodes in a plain-object tree.
 * Each key whose value is a non-null object or array counts as one node.
 */
function countNodes(value: unknown, path: string): { count: number; violatingPath: string | null } {
  if (value === null || typeof value !== "object") {
    return { count: 0, violatingPath: null };
  }

  let total = 1; // count this node
  const entries = Array.isArray(value)
    ? value.map((v, i) => [String(i), v] as [string, unknown])
    : (Object.entries(value as Record<string, unknown>));

  for (const [key, child] of entries) {
    const childPath = path ? `${path}.${key}` : key;
    const result = countNodes(child, childPath);
    total += result.count;
  }
  return { count: total, violatingPath: null };
}

/**
 * Recursively measures the maximum nesting depth of a plain-object tree.
 * Returns the deepest path along with the depth value.
 */
function measureDepth(
  value: unknown,
  currentDepth: number,
  path: string,
): { depth: number; deepestPath: string } {
  if (value === null || typeof value !== "object") {
    return { depth: currentDepth, deepestPath: path };
  }

  const entries = Array.isArray(value)
    ? value.map((v, i) => [String(i), v] as [string, unknown])
    : (Object.entries(value as Record<string, unknown>));

  if (entries.length === 0) {
    return { depth: currentDepth, deepestPath: path };
  }

  let maxDepth = currentDepth;
  let deepestPath = path;

  for (const [key, child] of entries) {
    const childPath = path ? `${path}.${key}` : key;
    const result = measureDepth(child, currentDepth + 1, childPath);
    if (result.depth > maxDepth) {
      maxDepth = result.depth;
      deepestPath = result.deepestPath;
    }
  }
  return { depth: maxDepth, deepestPath };
}

// ---------------------------------------------------------------------------
// PropStreamGuard class
// ---------------------------------------------------------------------------

/**
 * Stateful Guard-2 instance that accumulates metrics across multiple chunks
 * for the lifetime of a single stream session.
 */
export class PropStreamGuard {
  private totalNodes = 0;
  private totalPayloadBytes = 0;
  private maxObservedDepth = 0;

  constructor(private readonly contract: PropStreamContract) {}

  /** Reset all counters so the guard can be reused for a new stream. */
  reset(): void {
    this.totalNodes = 0;
    this.totalPayloadBytes = 0;
    this.maxObservedDepth = 0;
  }

  /**
   * Validate a single chunk against the contract.
   *
   * Returns { status: "SAFE" } when everything is within budget, or
   * { status: "VIOLATION", checkpoint } when a limit is exceeded.
   */
  validate(chunk: PropStreamChunk): GuardResult {
    const { data, byteLength } = chunk;

    // --- Node count ---
    const { count: chunkNodes } = countNodes(data, "");
    this.totalNodes += chunkNodes;

    // --- Payload bytes ---
    this.totalPayloadBytes += byteLength;

    // --- Nesting depth ---
    const { depth: chunkDepth, deepestPath } = measureDepth(data, 0, "");
    if (chunkDepth > this.maxObservedDepth) {
      this.maxObservedDepth = chunkDepth;
    }

    // --- Contract checks (first breach wins) ---
    let violatingPath: string | null = null;

    if (this.totalNodes > this.contract.maxNodes) {
      violatingPath = deepestPath || "root";
    } else if (this.maxObservedDepth > this.contract.maxDepth) {
      violatingPath = deepestPath;
    } else if (this.totalPayloadBytes > this.contract.maxPayloadBytes) {
      violatingPath = "payload";
    }

    if (violatingPath !== null) {
      const checkpoint: PropStreamCheckpoint = {
        violatingPath,
        remainingBudget: {
          nodes: Math.max(0, this.contract.maxNodes - this.totalNodes),
          depth: Math.max(0, this.contract.maxDepth - this.maxObservedDepth),
          payloadBytes: Math.max(0, this.contract.maxPayloadBytes - this.totalPayloadBytes),
        },
        timestamp: new Date().toISOString(),
        degradePolicy: this.contract.degradePolicy,
      };
      return { status: "VIOLATION", checkpoint };
    }

    return { status: "SAFE" };
  }

  /** Read-only snapshot of current accumulated metrics. */
  get metrics() {
    return {
      totalNodes: this.totalNodes,
      totalPayloadBytes: this.totalPayloadBytes,
      maxObservedDepth: this.maxObservedDepth,
    };
  }
}
