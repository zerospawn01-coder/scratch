/**
 * AuditHarnessPage.tsx – Phase 19: Audit Harness
 *
 * Wires PropStreamGuard, MockPropStreamService, and LivePulseTerminal together
 * into a single audit environment. Users can choose between a safe stream and a
 * stress test to observe Guard-2's behaviour in real time.
 */

import React, { useState, useCallback, useRef } from "react";
import type {
  PropStreamContract,
  PropStreamChunk,
  PropStreamCheckpoint,
} from "../types/constitution";
import { PropStreamGuard } from "../guards/PropStreamGuard";
import { MockPropStreamService } from "../services/MockPropStreamService";
import LivePulseTerminal, { type TerminalLine } from "../components/LivePulseTerminal";

// ---------------------------------------------------------------------------
// Default contract – tight budget so the stress test triggers quickly
// ---------------------------------------------------------------------------

const DEFAULT_CONTRACT: PropStreamContract = {
  maxNodes: 10,
  maxDepth: 5,
  maxPayloadBytes: 4096,
  degradePolicy: "SOFT_SUMMARY",
};

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

type StreamMode = "safe" | "stress";
type RunState = "idle" | "running" | "done";

const AuditHarnessPage: React.FC = () => {
  const [contract] = useState<PropStreamContract>(DEFAULT_CONTRACT);
  const [lines, setLines] = useState<TerminalLine[]>([]);
  const [guardStatus, setGuardStatus] = useState<"SAFE" | "VIOLATION" | "IDLE">("IDLE");
  const [checkpoint, setCheckpoint] = useState<PropStreamCheckpoint | null>(null);
  const [runState, setRunState] = useState<RunState>("idle");
  const [mode, setMode] = useState<StreamMode>("safe");

  // Stable refs so callbacks don't re-create on every render
  const guardRef = useRef(new PropStreamGuard(contract));
  const serviceRef = useRef(new MockPropStreamService());

  const handleChunk = useCallback((chunk: PropStreamChunk) => {
    const result = guardRef.current.validate(chunk);

    setLines((prev) => [
      ...prev,
      { seq: chunk.seq, chunk, guardResult: result },
    ]);

    if (result.status === "VIOLATION") {
      setGuardStatus("VIOLATION");
      setCheckpoint(result.checkpoint ?? null);
      // Stop further chunks after first violation
      serviceRef.current.stop();
    } else {
      setGuardStatus("SAFE");
    }
  }, []);

  const handleDone = useCallback(() => {
    setRunState("done");
  }, []);

  const handleStart = useCallback(() => {
    // Reset state
    guardRef.current.reset();
    setLines([]);
    setGuardStatus("IDLE");
    setCheckpoint(null);
    setRunState("running");

    serviceRef.current.start(mode, handleChunk, handleDone);
  }, [mode, handleChunk, handleDone]);

  const handleStop = useCallback(() => {
    serviceRef.current.stop();
    setRunState("idle");
  }, []);

  return (
    <div className="audit-harness">
      <header className="audit-harness__header">
        <h1 className="audit-harness__title">
          🛡 Phase 19 — Prop Streaming &amp; Guard-2 Audit Harness
        </h1>
        <p className="audit-harness__subtitle">
          Verify that Guard-2 enforces the <code>PropStreamContract</code> in real time.
        </p>
      </header>

      {/* Contract summary */}
      <section className="audit-harness__contract">
        <h2>Active Contract</h2>
        <table className="contract-table">
          <tbody>
            <tr><th>Max Nodes</th><td>{contract.maxNodes}</td></tr>
            <tr><th>Max Depth</th><td>{contract.maxDepth}</td></tr>
            <tr><th>Max Payload</th><td>{contract.maxPayloadBytes} B</td></tr>
            <tr><th>Degrade Policy</th><td><code>{contract.degradePolicy}</code></td></tr>
          </tbody>
        </table>
      </section>

      {/* Controls */}
      <section className="audit-harness__controls">
        <label className="audit-harness__mode-label">
          Stream scenario:&nbsp;
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as StreamMode)}
            disabled={runState === "running"}
          >
            <option value="safe">✅ Safe stream</option>
            <option value="stress">⚡ Stress test (triggers violation)</option>
          </select>
        </label>

        {runState !== "running" ? (
          <button className="btn btn--primary" onClick={handleStart}>
            ▶ Start stream
          </button>
        ) : (
          <button className="btn btn--danger" onClick={handleStop}>
            ■ Stop
          </button>
        )}

        {runState === "done" && (
          <span className="audit-harness__done-badge">Stream complete</span>
        )}
      </section>

      {/* Terminal */}
      <section className="audit-harness__terminal">
        <LivePulseTerminal
          lines={lines}
          guardStatus={guardStatus}
          checkpoint={checkpoint}
        />
      </section>

      {/* Checkpoint log */}
      {checkpoint && (
        <section className="audit-harness__checkpoint">
          <h2>📋 PropStreamCheckpoint (Audit Record)</h2>
          <pre className="checkpoint-pre">{JSON.stringify(checkpoint, null, 2)}</pre>
        </section>
      )}
    </div>
  );
};

export default AuditHarnessPage;
