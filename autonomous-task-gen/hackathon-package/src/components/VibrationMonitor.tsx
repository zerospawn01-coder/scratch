import React from "react";
import type { CausalForecast } from "../types/constitution";
import "./VibrationMonitor.css";

interface VibrationMonitorProps {
  forecast: CausalForecast | null;
}

const VibrationMonitor: React.FC<VibrationMonitorProps> = ({ forecast }) => {
  if (!forecast) {
    return (
      <div className="vibration-monitor vibration-monitor--idle">
        <div className="vibration-monitor__status">WAITING FOR SIGNAL...</div>
      </div>
    );
  }

  const { riskScore, recommendedTag, probablePath, rationale } = forecast;
  const isRising = probablePath === "RESISTANCE_RISE";

  return (
    <div className={`vibration-monitor ${isRising ? 'vibration-monitor--warning' : 'vibration-monitor--safe'}`}>
      <div className="vibration-monitor__header">
        <span className="material-icons">sensors</span>
        <h3>CAUSAL VIBRATION AUDIT</h3>
        <div className="vibration-monitor__tag">{recommendedTag}</div>
      </div>

      <div className="vibration-monitor__gauge">
        <div className="gauge-track">
          <div 
            className="gauge-fill" 
            style={{ width: `${riskScore * 100}%` }}
          />
        </div>
        <div className="gauge-labels">
          <span>0.0</span>
          <span>RISK: {riskScore.toFixed(3)}</span>
          <span>1.0</span>
        </div>
      </div>

      <div className="vibration-monitor__path">
        <span className="label">PREDICTED PATH:</span>
        <span className={`value ${probablePath.toLowerCase()}`}>{probablePath}</span>
      </div>

      <div className="vibration-monitor__rationale">
        <code>{rationale}</code>
      </div>

      {isRising && (
        <div className="vibration-monitor__alert">
          <span className="material-icons">priority_high</span>
          <span>CAUSAL COLLAPSE PROBABLE — RECOMMEND ABSTAIN OR HLG REVIEW</span>
        </div>
      )}
    </div>
  );
};

export default VibrationMonitor;
