/**
 * MockPropStreamService.ts – Phase 19: Streaming Simulator
 *
 * Provides two stream scenarios:
 *   • "safe"   – a well-behaved stream that stays within any reasonable budget.
 *   • "stress" – deliberately exceeds the node budget to trigger Guard-2.
 *
 * Each scenario yields PropStreamChunks at a configurable interval, mimicking
 * the incremental JSON delivery from a real AI producer.
 */

import type { PropStreamChunk } from "../types/constitution";

// ---------------------------------------------------------------------------
// Stream definitions
// ---------------------------------------------------------------------------

type StreamScenario = "safe" | "stress";

/** A raw data record used to build a chunk. */
type ChunkPayload = Record<string, unknown>;

const SAFE_CHUNKS: ChunkPayload[] = [
  { type: "header", title: "AI Response" },
  { type: "paragraph", text: "Materialising component tree…" },
  { type: "list", items: ["Item A", "Item B", "Item C"] },
  { type: "paragraph", text: "Rendering complete." },
  { type: "footer", note: "Stream ended normally." },
];

/**
 * Stress chunks intentionally create a deep, sprawling tree so Guard-2
 * detects a node-budget violation (with a contract of maxNodes:10, this
 * stream exceeds the limit by the 4th chunk).
 */
const STRESS_CHUNKS: ChunkPayload[] = [
  {
    type: "section",
    children: [
      { type: "row", cells: [{ v: 1 }, { v: 2 }, { v: 3 }] },
      { type: "row", cells: [{ v: 4 }, { v: 5 }, { v: 6 }] },
    ],
  },
  {
    type: "section",
    children: [
      { type: "row", cells: [{ v: 7 }, { v: 8 }] },
      { type: "row", cells: [{ v: 9 }, { v: 10 }] },
    ],
  },
  // Third chunk pushes well past a 10-node budget
  {
    type: "section",
    children: [
      { type: "row", cells: [{ v: 11 }, { v: 12 }, { v: 13 }, { v: 14 }] },
    ],
  },
  { type: "footer", note: "Intentional budget overflow." },
];

// ---------------------------------------------------------------------------
// MockPropStreamService
// ---------------------------------------------------------------------------

/** Callback fired for each streamed chunk. */
export type ChunkCallback = (chunk: PropStreamChunk) => void;

/** Callback fired when all chunks have been delivered. */
export type DoneCallback = () => void;

export class MockPropStreamService {
  private timer: ReturnType<typeof setTimeout> | null = null;
  private seq = 0;

  /**
   * Start streaming the chosen scenario.
   *
   * @param scenario   "safe" or "stress"
   * @param onChunk    called with each PropStreamChunk
   * @param onDone     called once all chunks have been sent
   * @param intervalMs delay between chunks in milliseconds (default 600)
   */
  start(
    scenario: StreamScenario,
    onChunk: ChunkCallback,
    onDone: DoneCallback,
    intervalMs = 600,
  ): void {
    this.stop();
    this.seq = 0;

    const payloads = scenario === "safe" ? SAFE_CHUNKS : STRESS_CHUNKS;
    let index = 0;

    const sendNext = () => {
      if (index >= payloads.length) {
        onDone();
        return;
      }

      const data = payloads[index++];
      const serialised = JSON.stringify(data);
      const chunk: PropStreamChunk = {
        data,
        byteLength: new TextEncoder().encode(serialised).length,
        seq: this.seq++,
      };

      onChunk(chunk);

      this.timer = setTimeout(sendNext, intervalMs);
    };

    this.timer = setTimeout(sendNext, intervalMs);
  }

  /** Cancel an in-progress stream. */
  stop(): void {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
}
