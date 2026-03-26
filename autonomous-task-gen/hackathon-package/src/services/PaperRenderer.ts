/**
 * PaperRenderer.ts – RGO ⑤ (view): Paper as Ledger View
 *
 * Generates a reproducible Markdown paper from a completed ResearchState.
 * The paper is NOT a separate document; it is a deterministic view of the
 * Ledger entries for a given research project.
 *
 * Design principle: "論文 = Ledgerのビュー" (Paper = Ledger's View)
 */

import type { ResearchState, GovernanceGateResult, LedgerEntry } from '../types/rgo';

export class PaperRenderer {
  /**
   * Render a Markdown paper from a completed ResearchState.
   * Throws if the research has not reached 'PAPER' phase or is not COMPLETED.
   */
  render(state: ResearchState): string {
    if (state.status !== 'COMPLETED') {
      throw new Error(
        `[RGO] PaperRenderer: Cannot render paper for research "${state.researchId}" ` +
        `with status "${state.status}". Only COMPLETED research can be rendered.`
      );
    }

    const lines: string[] = [];

    // Title
    lines.push(`# Research Paper`);
    lines.push(`**Research ID:** \`${state.researchId}\``);
    lines.push(`**Status:** ${state.status}`);
    lines.push(`**Rendered at:** ${new Date().toISOString()}`);
    lines.push('');

    // Abstract (Intent Layer)
    if (state.intent) {
      lines.push('## Abstract');
      lines.push(state.intent.problemStatement);
      lines.push('');
      lines.push(`**Importance:** ${state.intent.importance}`);
      lines.push(`**Keywords:** ${state.intent.keywords.join(', ')}`);
      lines.push('');
    }

    // Hypothesis (Formalization Layer)
    if (state.hypothesis) {
      lines.push('## Hypothesis');
      lines.push(`**H₁:** ${state.hypothesis.statement}`);
      lines.push('');
      lines.push(`**H₀:** ${state.hypothesis.nullHypothesis}`);
      lines.push('');

      if (state.hypothesis.causalModel) {
        lines.push(`**Causal Model:** ${state.hypothesis.causalModel}`);
        lines.push('');
      }

      if (state.hypothesis.constraints.length > 0) {
        lines.push('**Constraints:**');
        state.hypothesis.constraints.forEach(c => lines.push(`- ${c}`));
        lines.push('');
      }

      lines.push('### Metrics');
      lines.push('| Metric | Unit | Operator | Threshold | Reproducibility |');
      lines.push('|--------|------|----------|-----------|-----------------|');
      state.hypothesis.metrics.forEach(m => {
        lines.push(
          `| ${m.name} | ${m.unit} | ${m.operator} | ${m.threshold} | ${m.isReproducibilityMetric ? '✓' : '–'} |`
        );
      });
      lines.push('');
    }

    // Results (Execution Layer)
    if (state.experimentResult) {
      lines.push('## Results');
      lines.push(`**Experiment ID:** \`${state.experimentResult.experimentId}\``);
      lines.push(`**Executed at:** ${state.experimentResult.executedAt}`);
      lines.push(`**Reproducibility Hash:** \`${state.experimentResult.reproducibilityHash}\``);
      lines.push('');
      lines.push('### Observed Values');
      lines.push('| Metric ID | Observed Value |');
      lines.push('|-----------|----------------|');
      for (const [metricId, value] of Object.entries(state.experimentResult.observedValues)) {
        lines.push(`| ${metricId} | ${value} |`);
      }
      lines.push('');
    }

    // Governance audit (Governance Layer)
    if (state.gateResults.length > 0) {
      lines.push('## Governance Audit');
      state.gateResults.forEach(gate => {
        lines.push(`### Gate: ${gate.gateId} (${gate.kind})`);
        lines.push(`**Status:** ${gate.status}`);
        lines.push(`**Evaluated at:** ${gate.evaluatedAt}`);
        if (gate.violations.length > 0) {
          lines.push('**Violations:**');
          gate.violations.forEach(v =>
            lines.push(`- \`${v.code}\` – ${v.message}${v.path ? ` _(path: ${v.path})_` : ''}`)
          );
        }
        lines.push('');
      });
    }

    // Ledger (Ledger Layer)
    lines.push('## Ledger');
    lines.push('_All decisions are recorded in tamper-evident hash-chained entries._');
    lines.push('');
    lines.push('| Seq | Phase | Entry Hash | Previous Hash | Committed At |');
    lines.push('|-----|-------|------------|---------------|--------------|');
    state.ledgerEntries.forEach(entry => {
      lines.push(
        `| ${entry.ledgerSequence} | ${entry.phase} | \`${entry.entryHash}\` | \`${entry.previousHash}\` | ${entry.committedAt} |`
      );
    });
    lines.push('');

    lines.push('---');
    lines.push('_This paper is a deterministic view of the Research Ledger. It is not stored independently._');

    return lines.join('\n');
  }

  /**
   * Render a Markdown summary of governance gate results only (useful for auditors).
   */
  renderGateSummary(gateResults: readonly GovernanceGateResult[]): string {
    const lines: string[] = ['## Governance Gate Summary', ''];
    gateResults.forEach(gate => {
      const icon = gate.status === 'PASS' ? '✅' : '❌';
      lines.push(`${icon} **${gate.kind}** (\`${gate.gateId}\`) – ${gate.status}`);
      if (gate.violations.length > 0) {
        gate.violations.forEach(v => lines.push(`  - \`${v.code}\`: ${v.message}`));
      }
    });
    return lines.join('\n');
  }

  /**
   * Render a Markdown ledger audit trail (useful for reproducibility verification).
   */
  renderLedgerAudit(entries: readonly LedgerEntry[]): string {
    const lines: string[] = ['## Ledger Audit Trail', ''];
    entries.forEach(entry => {
      lines.push(`### Entry #${entry.ledgerSequence}: ${entry.phase}`);
      lines.push(`- **Research ID:** \`${entry.researchId}\``);
      lines.push(`- **Hash:** \`${entry.entryHash}\``);
      lines.push(`- **Previous:** \`${entry.previousHash}\``);
      lines.push(`- **Committed:** ${entry.committedAt}`);
      lines.push('');
    });
    return lines.join('\n');
  }
}
