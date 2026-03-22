/**
 * constitution.ts – Phase 19: Living UI & Runtime Guard (Guard-2)
 *
 * Defines the constitutional types that govern prop-streaming between an AI
 * producer and a React UI consumer. All streamed UI must operate within the
 * budget specified by a PropStreamContract and produce auditable checkpoints.
 */

// ---------------------------------------------------------------------------
// Degrade Policies
// ---------------------------------------------------------------------------

/** What the system does when a budget is exceeded. */
export type DegradePolicy = "SOFT_SUMMARY" | "HARD_ROLLBACK";

// ---------------------------------------------------------------------------
// PropStreamContract
// ---------------------------------------------------------------------------

/**
 * A binding agreement negotiated before streaming starts. The AI producer
 * promises to stay within these resource limits; the UI consumer enforces them
 * via Guard-2 on every chunk.
 */
export interface PropStreamContract {
  /** Maximum number of DOM-equivalent nodes allowed in the rendered output. */
  maxNodes: number;

  /** Maximum nesting depth of the JSON / component tree. */
  maxDepth: number;

  /** Maximum total byte size of the streamed payload. */
  maxPayloadBytes: number;

  /** What action Guard-2 takes when any limit is breached. */
  degradePolicy: DegradePolicy;
}

// ---------------------------------------------------------------------------
// Guard-2 Result
// ---------------------------------------------------------------------------

/** The outcome returned by Guard-2 after validating one chunk. */
export type GuardStatus = "SAFE" | "VIOLATION";

export interface GuardResult {
  status: GuardStatus;
  checkpoint?: PropStreamCheckpoint;
}

// ---------------------------------------------------------------------------
// PropStreamCheckpoint
// ---------------------------------------------------------------------------

/**
 * An immutable audit record produced the instant Guard-2 detects a violation.
 * Stores the exact path where the constraint was broken and the remaining
 * budget at that moment, enabling deterministic post-mortem analysis.
 */
export interface PropStreamCheckpoint {
  /** JSON path (dot-notation) inside the chunk where the violation occurred. */
  violatingPath: string;

  /** How much budget remained across all three dimensions when the breach occurred. */
  remainingBudget: {
    nodes: number;
    depth: number;
    payloadBytes: number;
  };

  /** ISO-8601 timestamp of when the violation was recorded. */
  timestamp: string;

  /** The degrade policy that was invoked. */
  degradePolicy: DegradePolicy;
}

// ---------------------------------------------------------------------------
// Stream Chunk
// ---------------------------------------------------------------------------

/** A single unit of work streamed from the AI producer. */
export interface PropStreamChunk {
  /** Opaque JSON data representing a partial or complete UI prop tree. */
  data: Record<string, unknown>;

  /** The byte length of the serialised chunk (caller must compute this). */
  byteLength: number;

  /** Sequence number for ordering and replay. */
  seq: number;
}
