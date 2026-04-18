import type { 
  SloConfiguration, 
  SloEvaluationResult, 
  PolicyConfiguration, 
  PolicyEvaluationResult,
  EvaluationDisposition,
  SloSeverity
} from '../types/governance';
import { GovernanceUtils } from './GovernanceUtils';

export class SloEngine {
  private cooldowns: Map<string, number> = new Map();

  /**
   * Evaluates a continuous metric against SLO thresholds and bands.
   */
  evaluateSLO(config: SloConfiguration, value: number): SloEvaluationResult {
    let disposition: EvaluationDisposition = 'ALLOW';
    let severity: SloSeverity | undefined;
    let breachDistance = 0;

    const { operator, value: thresholdValue } = config.threshold;
    const isBreached = this.compare(value, operator, thresholdValue);

    if (isBreached) {
      disposition = 'BLOCK'; // Default to BLOCK on breach for safety
      breachDistance = Math.abs(value - thresholdValue);

      if (config.bands) {
        if (config.bands.fatal !== undefined && this.compare(value, operator, config.bands.fatal)) {
          severity = 'FATAL';
        } else if (this.compare(value, operator, config.bands.critical)) {
          severity = 'CRITICAL';
        } else if (config.bands.warning !== undefined && this.compare(value, operator, config.bands.warning)) {
          severity = 'WARNING';
          disposition = 'ALLOW'; // Warnings might just notify
        }
      } else {
        severity = 'CRITICAL';
      }
    }

    return {
      sloId: config.sloId,
      disposition,
      severity,
      observedValue: value,
      breachDistance,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Evaluates discrete policies and handles deduplication/cooldown.
   */
  async evaluatePolicy(
    config: PolicyConfiguration, 
    triggerSurface: any
  ): Promise<PolicyEvaluationResult> {
    const now = Date.now();
    const lastEscalation = this.cooldowns.get(config.policyId) || 0;
    
    // Canonicalize only the specified surface fields
    const surfaceSubset: Record<string, any> = {};
    config.dedupeKeySurface.forEach(key => {
      surfaceSubset[key] = triggerSurface[key];
    });

    const canonical = GovernanceUtils.canonicalize(surfaceSubset);
    const snapshotHash = await GovernanceUtils.generateHash(canonical);

    if (now - lastEscalation < config.cooldownMs) {
      return {
        policyId: config.policyId,
        disposition: 'DEDUPE',
        snapshotHash,
        timestamp: new Date(now).toISOString()
      };
    }

    // If it's a violation but not deduped, we escalate
    this.cooldowns.set(config.policyId, now);

    return {
      policyId: config.policyId,
      disposition: 'ESCALATE',
      snapshotHash,
      timestamp: new Date(now).toISOString()
    };
  }

  private compare(a: number, op: 'GT' | 'LT' | 'EQ', b: number): boolean {
    switch (op) {
      case 'GT': return a > b;
      case 'LT': return a < b;
      case 'EQ': return a === b;
      default: return false;
    }
  }
}
