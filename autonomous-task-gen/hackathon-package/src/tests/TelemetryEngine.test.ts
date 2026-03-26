import { describe, expect, it, vi } from "vitest";
import { AuthorizationWal } from "../services/AuthorizationWal";
import { PropStreamTelemetryEngine } from "../services/PropStreamTelemetryEngine";

describe("AuthorizationWal", () => {
  it("creates different chained hashes for sequential atoms", () => {
    const wal = new AuthorizationWal();

    const first = wal.appendAtomic({
      runId: "run_1",
      streamMode: "safe",
      outcome: "SAFE_COMPLETE",
    });

    const second = wal.appendAtomic({
      runId: "run_2",
      streamMode: "stress",
      outcome: "VIOLATION",
      violatingPath: "root.children.0",
      degradePolicy: "SOFT_SUMMARY",
    });

    expect(first.walCommitHash).toMatch(/^wal_[0-9a-f]{8}$/);
    expect(second.walCommitHash).toMatch(/^wal_[0-9a-f]{8}$/);
    expect(first.walSequence).toBe(1);
    expect(second.walSequence).toBe(2);
    expect(first.walCommitHash).not.toBe(second.walCommitHash);
  });

  it("produces the same hash for identical first atom regardless of timestamp", () => {
    vi.useFakeTimers();

    const walA = new AuthorizationWal();
    vi.setSystemTime(new Date("2026-01-01T00:00:00.000Z"));
    const atomA = walA.appendAtomic({
      runId: "run_same",
      streamMode: "safe",
      outcome: "SAFE_COMPLETE",
    });

    const walB = new AuthorizationWal();
    vi.setSystemTime(new Date("2030-01-01T00:00:00.000Z"));
    const atomB = walB.appendAtomic({
      runId: "run_same",
      streamMode: "safe",
      outcome: "SAFE_COMPLETE",
    });

    expect(atomA.timestamp).not.toBe(atomB.timestamp);
    expect(atomA.walCommitHash).toBe(atomB.walCommitHash);

    vi.useRealTimers();
  });
});

describe("PropStreamTelemetryEngine", () => {
  it("records WAL atoms and returns newest-first events", () => {
    const wal = new AuthorizationWal();
    const telemetry = new PropStreamTelemetryEngine();

    const first = wal.appendAtomic({
      runId: "run_1",
      streamMode: "safe",
      outcome: "SAFE_COMPLETE",
    });

    const second = wal.appendAtomic({
      runId: "run_2",
      streamMode: "stress",
      outcome: "VIOLATION",
      violatingPath: "payload",
      degradePolicy: "HARD_ROLLBACK",
    });

    telemetry.recordWalAudit(first);
    telemetry.recordWalAudit(second);

    const events = telemetry.getEvents(10);
    expect(events).toHaveLength(2);
    expect(events[0].walSequence).toBe(2);
    expect(events[0].runId).toBe("run_2");
    expect(events[0].walCommitHash).toBe(second.walCommitHash);
    expect(events[0].rawAtom).toEqual(second);
    expect(events[1].walSequence).toBe(1);
    expect(events[1].runId).toBe("run_1");
    expect(events[1].rawAtom).toEqual(first);
  });
});
