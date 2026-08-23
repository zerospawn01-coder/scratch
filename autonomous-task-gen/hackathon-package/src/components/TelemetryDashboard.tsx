import React, { useMemo, useState } from "react";
import type { TelemetryAuditEvent } from "../types/constitution";

interface TelemetryDashboardProps {
  events: TelemetryAuditEvent[];
}

const TelemetryDashboard: React.FC<TelemetryDashboardProps> = ({ events }) => {
  const [modeFilter, setModeFilter] = useState<"ALL" | "safe" | "stress">("ALL");
  const [outcomeFilter, setOutcomeFilter] = useState<"ALL" | "SAFE_COMPLETE" | "VIOLATION">("ALL");
  const [expandedHash, setExpandedHash] = useState<string | null>(null);

  const filteredEvents = useMemo(() => {
    return events.filter((event) => {
      const modeMatches = modeFilter === "ALL" || event.streamMode === modeFilter;
      const outcomeMatches = outcomeFilter === "ALL" || event.outcome === outcomeFilter;
      return modeMatches && outcomeMatches;
    });
  }, [events, modeFilter, outcomeFilter]);

  return (
    <section className="telemetry-dashboard" aria-label="WAL Audit Trail">
      <div className="telemetry-dashboard__header">
        <h2>WAL Audit Trail</h2>
        <span className="telemetry-dashboard__count">{filteredEvents.length} / {events.length} events</span>
      </div>

      <div className="telemetry-dashboard__filters">
        <label className="telemetry-dashboard__filter">
          Mode
          <select value={modeFilter} onChange={(e) => setModeFilter(e.target.value as "ALL" | "safe" | "stress")}>
            <option value="ALL">ALL</option>
            <option value="safe">safe</option>
            <option value="stress">stress</option>
          </select>
        </label>

        <label className="telemetry-dashboard__filter">
          Outcome
          <select
            value={outcomeFilter}
            onChange={(e) => setOutcomeFilter(e.target.value as "ALL" | "SAFE_COMPLETE" | "VIOLATION")}
          >
            <option value="ALL">ALL</option>
            <option value="SAFE_COMPLETE">SAFE_COMPLETE</option>
            <option value="VIOLATION">VIOLATION</option>
          </select>
        </label>
      </div>

      {events.length === 0 ? (
        <p className="telemetry-dashboard__empty">No audit events yet. Start a stream to generate WAL commits.</p>
      ) : filteredEvents.length === 0 ? (
        <p className="telemetry-dashboard__empty">No events match the current filters.</p>
      ) : (
        <div className="telemetry-dashboard__table-wrap">
          <table className="telemetry-dashboard__table">
            <thead>
              <tr>
                <th>Seq</th>
                <th>Run ID</th>
                <th>Mode</th>
                <th>Outcome</th>
                <th>WAL Hash</th>
                <th>Timestamp</th>
                <th>Path</th>
              </tr>
            </thead>
            <tbody>
              {filteredEvents.map((event) => {
                const rowKey = `${event.runId}:${event.walCommitHash}`;
                const isExpanded = expandedHash === event.walCommitHash;

                return (
                  <React.Fragment key={rowKey}>
                    <tr>
                      <td>{event.walSequence}</td>
                      <td><code>{event.runId}</code></td>
                      <td>{event.streamMode}</td>
                      <td>
                        <span
                          className={`telemetry-dashboard__outcome telemetry-dashboard__outcome--${event.outcome.toLowerCase()}`}
                        >
                          {event.outcome}
                        </span>
                      </td>
                      <td>
                        <button
                          type="button"
                          className="telemetry-dashboard__hash-btn"
                          onClick={() => setExpandedHash(isExpanded ? null : event.walCommitHash)}
                        >
                          <code>{event.walCommitHash}</code>
                        </button>
                      </td>
                      <td>{event.timestamp}</td>
                      <td><code>{event.violatingPath ?? "-"}</code></td>
                    </tr>
                    {isExpanded && (
                      <tr className="telemetry-dashboard__expanded-row">
                        <td colSpan={7}>
                          <pre className="telemetry-dashboard__raw-json">
                            {JSON.stringify(event.rawAtom, null, 2)}
                          </pre>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
};

export default TelemetryDashboard;
