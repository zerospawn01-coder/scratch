import { describe, expect, it, vi } from "vitest";
import { MockPropStreamService } from "../services/MockPropStreamService";

describe("MockPropStreamService", () => {
  it("emits vibration before chunk for each step", () => {
    vi.useFakeTimers();

    const service = new MockPropStreamService();
    const order: string[] = [];

    service.start(
      "safe",
      () => order.push("chunk"),
      () => order.push("done"),
      () => order.push("vibration"),
      300,
    );

    // initial trigger
    vi.advanceTimersByTime(100);
    expect(order[0]).toBe("vibration");

    // pre-chunk delay
    vi.advanceTimersByTime(200);
    expect(order[1]).toBe("chunk");

    service.stop();
    vi.useRealTimers();
  });

  it("prevents chunk emission after stop during pre-chunk delay", () => {
    vi.useFakeTimers();

    const service = new MockPropStreamService();
    let vibrationCount = 0;
    let chunkCount = 0;

    service.start(
      "stress",
      () => {
        chunkCount += 1;
      },
      () => {
        // no-op
      },
      () => {
        vibrationCount += 1;
      },
      300,
    );

    // trigger first vibration
    vi.advanceTimersByTime(100);
    expect(vibrationCount).toBe(1);

    // stop before the 200ms pre-chunk delay elapses
    service.stop();

    vi.advanceTimersByTime(1000);
    expect(chunkCount).toBe(0);

    vi.useRealTimers();
  });
});
