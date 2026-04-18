import React from "react";
import type { NomosMutation } from "../types/constitution";
import "./MutationApprovalPanel.css";

interface MutationApprovalPanelProps {
  mutations: NomosMutation[];
  onApprove: (mutationId: string) => void;
  onReject: (mutationId: string) => void;
}

const MutationApprovalPanel: React.FC<MutationApprovalPanelProps> = ({
  mutations,
  onApprove,
  onReject,
}) => {
  if (mutations.length === 0) {
    return (
      <div className="mutation-panel mutation-panel--empty">
        <p>No structural mutations proposed yet.</p>
      </div>
    );
  }

  return (
    <div className="mutation-panel">
      <h3 className="mutation-panel__title">🧬 Pending Structural Mutations</h3>
      <div className="mutation-list">
        {mutations.map((m) => (
          <div key={m.mutationId} className={`mutation-item mutation-item--${m.status.toLowerCase()}`}>
            <div className="mutation-item__header">
              <span className="mutation-badge">{m.target} : {m.action}</span>
              <span className="mutation-id">{m.mutationId}</span>
            </div>
            
            <p className="mutation-rationale">{m.rationale}</p>
            
            <div className="mutation-metrics">
              <div className="metric">
                <span className="metric__label">Risk Score:</span>
                <div className="risk-bar">
                  <div 
                    className="risk-bar__fill" 
                    style={{ 
                      width: `${m.vulnerabilityRisk * 100}%`,
                      background: m.vulnerabilityRisk > 0.5 ? "var(--accent-red)" : "var(--accent-cyan)"
                    }} 
                  />
                </div>
                <span className="metric__value">{(m.vulnerabilityRisk * 100).toFixed(0)}%</span>
              </div>
              
              <div className="metric">
                <span className="metric__label">Projected R:</span>
                <span className="metric__value">{(m.projectedR * 100).toFixed(1)}%</span>
              </div>
            </div>

            {m.status === "PENDING" && (
              <div className="mutation-actions">
                <button 
                  className="btn btn--primary btn--small" 
                  onClick={() => onApprove(m.mutationId)}
                >
                  Approve Mutation
                </button>
                <button 
                  className="btn btn--danger btn--small" 
                  onClick={() => onReject(m.mutationId)}
                >
                  Reject
                </button>
              </div>
            )}
            
            {m.status === "APPROVED" && <div className="status-indicator status-indicator--approved">APPLIED</div>}
            {m.status === "REJECTED" && <div className="status-indicator status-indicator--rejected">REJECTED</div>}
          </div>
        ))}
      </div>
    </div>
  );
};

export default MutationApprovalPanel;
