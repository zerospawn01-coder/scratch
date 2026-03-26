/**
 * AuditHarnessPage.tsx – Phase 33: Self-Architecting Nomos
 *
 * Wires PropStreamGuard, MockPropStreamService, VibrationSensor, and 
 * NomosMutationEngine together. Allows for predictive blocking and 
 * structural mutation approvals.
 */

import React, { useState, useCallback, useRef, useEffect } from "react";
import type {
  PropStreamContract,
  PropStreamChunk,
  PropStreamCheckpoint,
  TelemetryAuditEvent,
  CausalForecast,
  NomosMutation,
} from "../types/constitution";
import { PropStreamGuard } from "../guards/PropStreamGuard";
import { MockPropStreamService } from "../services/MockPropStreamService";
import { AuthorizationWal } from "../services/AuthorizationWal";
import { PropStreamTelemetryEngine } from "../services/PropStreamTelemetryEngine";
import { VibrationSensor } from "../services/VibrationSensor";
import { NomosMutationEngine } from "../services/NomosMutationEngine";
import LivePulseTerminal, { type TerminalLine } from "../components/LivePulseTerminal";
import TelemetryDashboard from "../components/TelemetryDashboard";
import VibrationMonitor from "../components/VibrationMonitor";
import MutationApprovalPanel from "../components/MutationApprovalPanel";

import { SloEngine } from "../services/SloEngine";
import { PlaybookRunner } from "../services/PlaybookRunner";
import type { SloConfiguration, PolicyConfiguration } from "../types/governance";

const DEFAULT_CONTRACT: PropStreamContract = {
  maxNodes: 10,
  maxDepth: 5,
  maxPayloadBytes: 4096,
  degradePolicy: "SOFT_SUMMARY",
};

// Phase 34: Hardened SLO/Policy Configurations
const LATENCY_SLO: SloConfiguration = {
  sloId: "PREDICTION_LATENCY",
  kind: "SLO",
  threshold: { operator: "GT", value: 200, unit: "ms" },
  bands: { warning: 100, critical: 200, fatal: 500 }
};

const ESCALATION_POLICY: PolicyConfiguration = {
  policyId: "HITL_ESCALATION_COOLDOWN",
  kind: "POLICY",
  cooldownMs: 300000, // 5 min
  dedupeKeySurface: ["action", "target"]
};

type StreamMode = "safe" | "stress";
type RunState = "idle" | "running" | "done";

function generateRunId(): string {
  const randomPart = Math.random().toString(36).slice(2, 8);
  return `run_${Date.now()}_${randomPart}`;
}

const AuditHarnessPage: React.FC = () => {
  const [contract, setContract] = useState<PropStreamContract>(DEFAULT_CONTRACT);
  const [lines, setLines] = useState<TerminalLine[]>([]);
  const [guardStatus, setGuardStatus] = useState<"SAFE" | "VIOLATION" | "IDLE">("IDLE");
  const [checkpoint, setCheckpoint] = useState<PropStreamCheckpoint | null>(null);
  const [runState, setRunState] = useState<RunState>("idle");
  const [mode, setMode] = useState<StreamMode>("safe");
  const [events, setEvents] = useState<TelemetryAuditEvent[]>([]);
  const [vibrationForecast, setVibrationForecast] = useState<CausalForecast | null>(null);
  const [mutations, setMutations] = useState<NomosMutation[]>([]);
  const [autoBlock, setAutoBlock] = useState(true);

  const guardRef = useRef(new PropStreamGuard(contract));
  const serviceRef = useRef(new MockPropStreamService());
  const walRef = useRef(new AuthorizationWal());
  const telemetryRef = useRef(new PropStreamTelemetryEngine());
  const vibrationRef = useRef(new VibrationSensor());
  const mutationEngineRef = useRef(new NomosMutationEngine());
  
  // Phase 34 services
  const sloEngineRef = useRef(new SloEngine());
  const playbookRunnerRef = useRef(new PlaybookRunner(walRef.current, telemetryRef.current));

  const runIdRef = useRef<string>("");
  const violationRecordedRef = useRef(false);

  // Keep Guard-2 synced with the active contract after approved mutations.
  useEffect(() => {
    guardRef.current = new PropStreamGuard(contract);
    mutationEngineRef.current.reset();
  }, [contract]);

  // Reset mutation engine when switching scenarios
  useEffect(() => {
    mutationEngineRef.current.reset();
  }, [mode]);

  /**
   * Safe WAL wrapper to ensure Audit Write Synergy (Fail-closed)
   */
  const recordAudit = useCallback((input: any) => {
    try {
      const atom = walRef.current.appendAtomic(input);
      telemetryRef.current.recordWalAudit(atom);
      setEvents(telemetryRef.current.getEvents(30));
    } catch (err) {
      console.error("[SINCERE] CRITICAL: WAL Write Failure. Halting system.", err);
      handleStop();
      throw err;
    }
  }, []);

  const handleChunk = useCallback((chunk: PropStreamChunk) => {
    const start = performance.now();
    const result = guardRef.current.validate(chunk);
    const latency = performance.now() - start;

    // Phase 34: Evaluate Latency SLO
    const sloResult = sloEngineRef.current.evaluateSLO(LATENCY_SLO, latency);
    if (sloResult.disposition === 'BLOCK') {
      console.warn("[SINCERE] SLO BREACH: Latency exceeded critical threshold.", sloResult);
      handlePredictiveBlock("SLO_LATENCY_BREACH");
      return;
    }

    setLines((prev) => [
      ...prev,
      { seq: chunk.seq, chunk, guardResult: result },
    ]);

    if (result.status === "VIOLATION") {
      setGuardStatus("VIOLATION");
      setCheckpoint(result.checkpoint ?? null);
      if (!violationRecordedRef.current) {
        violationRecordedRef.current = true;
        recordAudit({
          runId: runIdRef.current,
          streamMode: mode,
          outcome: "VIOLATION",
          violatingPath: result.checkpoint?.violatingPath,
          degradePolicy: result.checkpoint?.degradePolicy,
        });
      }
      serviceRef.current.stop();
      setRunState("done");
    } else {
      setGuardStatus("SAFE");
    }
  }, [mode, recordAudit]);

  const handleDone = useCallback(() => {
    if (!violationRecordedRef.current) {
      recordAudit({
        runId: runIdRef.current,
        streamMode: mode,
        outcome: "SAFE_COMPLETE",
      });
    }
    setRunState("done");
  }, [mode, recordAudit]);

  const handlePredictiveBlock = useCallback((reason: string = "PREDICTIVE_CAUSAL_SHIELD") => {
    serviceRef.current.stop();
    setRunState("done");
    setGuardStatus("VIOLATION"); // Mark as blocked
    
    const virtualCheckpoint: PropStreamCheckpoint = {
      violatingPath: reason,
      remainingBudget: { nodes: 0, depth: 0, payloadBytes: 0 },
      timestamp: new Date().toISOString(),
      degradePolicy: contract.degradePolicy,
    };
    setCheckpoint(virtualCheckpoint);

    recordAudit({
      runId: runIdRef.current,
      streamMode: mode,
      outcome: "VIOLATION",
      violatingPath: reason,
      degradePolicy: contract.degradePolicy,
    });
    
    violationRecordedRef.current = true;
  }, [contract.degradePolicy, mode, recordAudit]);

  const handleStart = useCallback(() => {
    guardRef.current.reset();
    runIdRef.current = generateRunId();
    violationRecordedRef.current = false;
    setLines([]);
    setGuardStatus("IDLE");
    setCheckpoint(null);
    setRunState("running");

    serviceRef.current.start(
      mode, 
      handleChunk, 
      handleDone, 
      async (signal) => {
        const forecast = vibrationRef.current.forecast(signal);
        setVibrationForecast(forecast);

        // Phase 32: Predictive Blocking
        if (autoBlock && forecast.riskScore > 0.6 && forecast.probablePath === "RESISTANCE_RISE") {
          handlePredictiveBlock();
          return;
        }

        // Phase 33: Structural mutation proposal
        const mutation = mutationEngineRef.current.processForecast(forecast);
        if (mutation) {
          // Phase 34: Evaluate Policy (Cooldown/Dedupe) before adding to UI
          const policyResult = await sloEngineRef.current.evaluatePolicy(ESCALATION_POLICY, mutation);
          if (policyResult.disposition === 'DEDUPE') {
             console.log("[SINCERE] Policy: DEDUPE active for mutation.", policyResult.snapshotHash);
             return; 
          }

          setMutations(prev => {
            if (prev.some(p => p.action === mutation.action && p.status === "PENDING")) return prev;
            
            // Phase 34: Start Mutation with Playbook Task (60s Timeout)
            playbookRunnerRef.current.startMutation(mutation, 60000, (outcome) => {
               console.warn("[SINCERE] Playbook Timeout:", outcome);
               setMutations(m => m.map(item => 
                 item.mutationId === outcome.mutationId ? { ...item, status: "REJECTED" as const } : item
               ));
            });

            return [mutation, ...prev];
          });
        }
      }
    );
  }, [mode, handleChunk, handleDone, autoBlock, handlePredictiveBlock]);

  const handleStop = useCallback(() => {
    serviceRef.current.stop();
    setRunState("idle");
  }, []);

  const handleApproveMutation = useCallback((mutationId: string) => {
    const mutation = mutations.find(m => m.mutationId === mutationId);
    if (!mutation) return;

    // Phase 34: Use PlaybookRunner for consistent audit and synergy
    playbookRunnerRef.current.handleDecision(mutation, 'APPROVE');
    
    setMutations(prev => prev.map(m => 
      m.mutationId === mutationId ? { ...m, status: "APPROVED" as const } : m
    ));

    // Update Dashboard Events
    setEvents(telemetryRef.current.getEvents(30));

    // Simulate structural change by loosening the contract
    setContract(prev => ({
      ...prev,
      maxNodes: prev.maxNodes + 10,
    }));
  }, [mutations]);

  const handleRejectMutation = useCallback((mutationId: string) => {
    const mutation = mutations.find(m => m.mutationId === mutationId);
    if (!mutation) return;

    // Phase 34: Use PlaybookRunner
    playbookRunnerRef.current.handleDecision(mutation, 'REJECT');

    setMutations(prev => prev.map(m => 
      m.mutationId === mutationId ? { ...m, status: "REJECTED" as const } : m
    ));

    setEvents(telemetryRef.current.getEvents(30));
  }, [mutations]);

  return (
    <div className="audit-harness">
      <header className="audit-harness__header">
        <h1 className="audit-harness__title">
          🛡 Phase 33+ — Evolutionary Audit Dashboard
        </h1>
        <p className="audit-harness__subtitle">
          Real-time Causal Synthesis | Structural Mutation | HITL Governance
        </p>
      </header>

      <div className="audit-harness__dashboard">
        {/* Main Interaction Pane */}
        <main className="audit-harness__main-pane">
          {/* Controls Bar */}
          <section className="audit-harness__controls-bar">
            <div className="audit-harness__controls-bar-left">
              <select
                title="Select stream scenario"
                value={mode}
                onChange={(e) => setMode(e.target.value as StreamMode)}
                disabled={runState === "running"}
                className="audit-harness__select"
              >
                <option value="safe">✅ Safe Mode</option>
                <option value="stress">⚡ Stress Mode</option>
              </select>

              <label className="audit-harness__checkbox-label">
                <input 
                  type="checkbox" 
                  checked={autoBlock} 
                  onChange={(e) => setAutoBlock(e.target.checked)} 
                />
                Auto-block Risk
              </label>
            </div>

            <div className="audit-harness__controls-bar-right">
              {runState !== "running" ? (
                <button className="btn btn--primary" onClick={handleStart}>
                  ▶ Start Stream
                </button>
              ) : (
                <button className="btn btn--danger" onClick={handleStop}>
                  ■ Stop
                </button>
              )}
            </div>
          </section>

          {/* Terminal View */}
          <section className="audit-harness__terminal">
            <LivePulseTerminal
              lines={lines}
              guardStatus={guardStatus}
              checkpoint={checkpoint}
            />
          </section>

          {/* Audit Trail (Telemetery) */}
          <TelemetryDashboard events={events} />
        </main>

        {/* Side Monitoring Pane */}
        <aside className="audit-harness__side-pane">
          {/* Compact Contract Stats */}
          <section className="audit-harness__sidebar-section">
            <h2 className="audit-harness__sidebar-title">ACTIVE NOMOS</h2>
            <table className="contract-table">
              <tbody>
                <tr><th>Nodes</th><td>{contract.maxNodes}</td></tr>
                <tr><th>Depth</th><td>{contract.maxDepth}</td></tr>
                <tr><th>Policy</th><td><code>{contract.degradePolicy}</code></td></tr>
              </tbody>
            </table>
          </section>

          {/* Real-time Forecast */}
          <section className="audit-harness__sidebar-section">
            <h2 className="audit-harness__sidebar-title">CAUSAL VIBRATION</h2>
            <VibrationMonitor forecast={vibrationForecast} />
          </section>

          {/* Pending Proposals */}
          <MutationApprovalPanel 
            mutations={mutations} 
            onApprove={handleApproveMutation}
            onReject={handleRejectMutation}
          />
          
          {/* Virtual Checkpoint details */}
          {checkpoint && (
            <section className="audit-harness__sidebar-section checkpoint-card--blocked">
              <h2 className="audit-harness__sidebar-title audit-harness__sidebar-title--danger">LAST BLOCK Rationale</h2>
              <p className="checkpoint-card__path">{checkpoint.violatingPath}</p>
              <code style={{ fontSize: '10px', color: '#888' }}>{checkpoint.timestamp}</code>
            </section>
          )}
        </aside>
      </div>
    </div>
  );
};

export default AuditHarnessPage;
