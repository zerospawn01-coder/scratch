/**
 * MockPropStreamService.ts – Phase 32: Predictive Streaming Simulator
 *
 * Provides two stream scenarios:
 *   • "safe"   – a well-behaved stream.
 *   • "stress" – deliberately exceeds the node budget.
 *
 * Each scenario now yields "VibrationSignal" telemetry before each chunk,
 * allowing the UI to forecast risks in real time.
 */

import type { PropStreamChunk, VibrationSignal } from "../types/constitution";

type StreamScenario = "safe" | "stress";
type ChunkPayload = Record<string, unknown>;

const SAFE_CHUNKS: ChunkPayload[] = [
  { type: "header", title: "AI Response" },
  { type: "paragraph", text: "Materialising component tree…" },
  { type: "list", items: ["Item A", "Item B", "Item C"] },
  { type: "paragraph", text: "Rendering complete." },
  { type: "footer", note: "Stream ended normally." },
];

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
  {
    type: "section",
    children: [
      { type: "row", cells: [{ v: 11 }, { v: 12 }, { v: 13 }, { v: 14 }] },
    ],
  },
  { type: "footer", note: "Intentional budget overflow." },
];

export type ChunkCallback = (chunk: PropStreamChunk) => void;
export type DoneCallback = () => void;
export type VibrationCallback = (signal: VibrationSignal) => void;

export class MockPropStreamService {
  private timer: ReturnType<typeof setTimeout> | null = null;
  private preChunkTimer: ReturnType<typeof setTimeout> | null = null;
  private active = false;
  private seq = 0;

  start(
    scenario: StreamScenario,
    onChunk: ChunkCallback,
    onDone: DoneCallback,
    onVibration?: VibrationCallback,
    intervalMs = 800,
  ): void {
    this.stop();
    this.active = true;
    this.seq = 0;

    const payloads = scenario === "safe" ? SAFE_CHUNKS : STRESS_CHUNKS;
    let index = 0;

    const sendNext = () => {
      if (!this.active) {
        return;
      }

      if (index >= payloads.length) {
        onDone();
        return;
      }

      // 1. Simulate "Vibration" before sending the chunk
      if (onVibration) {
        const entropyBase = scenario === "stress" ? 1.4 : 0.3;
        const noise = Math.random() * 0.3;
        onVibration({
          sourceId: "ai_producer_telemetry",
          entropy: entropyBase + noise,
          gradient: 0.6 + (Math.random() * 0.4),
          confidence: scenario === "safe" ? 0.95 : 0.65,
          observedAt: new Date().toISOString(),
        });
      }

      // 2. Small delay (200ms) to allow UI to react to vibration before chunk arrives
      this.preChunkTimer = setTimeout(() => {
        if (!this.active) {
          return;
        }

        const currentData = payloads[index++];
        const serialised = JSON.stringify(currentData);
        const chunk: PropStreamChunk = {
          data: currentData,
          byteLength: new TextEncoder().encode(serialised).length,
          seq: this.seq++,
        };

        onChunk(chunk);
        this.timer = setTimeout(sendNext, intervalMs);
      }, 200);
    };

    // Initial trigger
    this.timer = setTimeout(sendNext, 100);
  }

  stop(): void {
    this.active = false;

    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.preChunkTimer !== null) {
      clearTimeout(this.preChunkTimer);
      this.preChunkTimer = null;
    }
  }
}
