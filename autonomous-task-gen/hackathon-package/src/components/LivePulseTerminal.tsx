/**
 * LivePulseTerminal.tsx – Phase 19: Live Streaming Visualiser
 *
 * Renders each incoming PropStreamChunk as a new line in a scrolling terminal.
 * A Guard-2 status badge shows SAFE (green) or VIOLATION (red) in real time.
 * When a VIOLATION is detected the degrade overlay is shown above the log.
 */

import React, { useEffect, useRef } from "react";
import type { PropStreamChunk, GuardResult, PropStreamCheckpoint } from "../types/constitution";
import "./LivePulseTerminal.css";

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface GuardBadgeProps {
  status: "SAFE" | "VIOLATION" | "IDLE";
}

const GuardBadge: React.FC<GuardBadgeProps> = ({ status }) => (
  <span className={`guard-badge guard-badge--${status.toLowerCase()}`}>
    Guard-2: {status}
  </span>
);

interface DegradeOverlayProps {
  checkpoint: PropStreamCheckpoint;
}

const DegradeOverlay: React.FC<DegradeOverlayProps> = ({ checkpoint }) => (
  <div className="degrade-overlay" role="alert" aria-live="assertive">
    <div className="degrade-overlay__inner">
      <h3 className="degrade-overlay__title">⚠ DEGRADE POLICY ACTIVATED</h3>
      <p className="degrade-overlay__policy">{checkpoint.degradePolicy}</p>
      <dl className="degrade-overlay__details">
        <dt>Violating path</dt>
        <dd><code>{checkpoint.violatingPath}</code></dd>
        <dt>Remaining budget (nodes)</dt>
        <dd>{checkpoint.remainingBudget.nodes}</dd>
        <dt>Remaining budget (bytes)</dt>
        <dd>{checkpoint.remainingBudget.payloadBytes}</dd>
        <dt>Detected at</dt>
        <dd>{checkpoint.timestamp}</dd>
      </dl>
    </div>
  </div>
);

// ---------------------------------------------------------------------------
// Log line
// ---------------------------------------------------------------------------

export interface TerminalLine {
  seq: number;
  chunk: PropStreamChunk;
  guardResult: GuardResult;
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export interface LivePulseTerminalProps {
  lines: TerminalLine[];
  guardStatus: "SAFE" | "VIOLATION" | "IDLE";
  checkpoint: PropStreamCheckpoint | null;
}

const LivePulseTerminal: React.FC<LivePulseTerminalProps> = ({
  lines,
  guardStatus,
  checkpoint,
}) => {
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to newest line
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [lines.length]);

  return (
    <div className="live-pulse-terminal" aria-label="Live Pulse Terminal">
      {/* Header bar */}
      <div className="live-pulse-terminal__header">
        <span className="live-pulse-terminal__title">📡 Live Pulse Terminal</span>
        <GuardBadge status={guardStatus} />
      </div>

      {/* Degrade overlay (shown on violation) */}
      {guardStatus === "VIOLATION" && checkpoint && (
        <DegradeOverlay checkpoint={checkpoint} />
      )}

      {/* Scrolling log */}
      <div className="live-pulse-terminal__log" role="log" aria-live="polite">
        {lines.length === 0 && (
          <p className="live-pulse-terminal__empty">Awaiting stream…</p>
        )}
        {lines.map((line) => (
          <div
            key={line.seq}
            className={`terminal-line terminal-line--${line.guardResult.status.toLowerCase()}`}
          >
            <span className="terminal-line__seq">[{line.seq}]</span>
            <span className="terminal-line__status">
              {line.guardResult.status === "SAFE" ? "✓" : "✗"}
            </span>
            <code className="terminal-line__data">
              {JSON.stringify(line.chunk.data)}
            </code>
            <span className="terminal-line__bytes">{line.chunk.byteLength}B</span>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
    </div>
  );
};

export default LivePulseTerminal;
