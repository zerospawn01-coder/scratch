/**
 * ResearchPipeline.ts – RGO: Full 5-Layer Orchestrator
 *
 * Implements the canonical RGO execution flow:
 *
 *   Idea
 *    ↓  (prohibited: direct execution)
 *   [Intent Structuring]    ← ResearchCompiler.buildIntent()
 *    ↓
 *   [Formalization]         ← ResearchCompiler.compile()
 *    ↓
 *   [Governance Gate①]      ← GovernanceGate.evaluatePreExecution()  (Fail-Closed)
 *    ↓
 *   [Execution]             ← caller-supplied ExperimentSpec + ExperimentResult
 *    ↓
 *   [Governance Gate②]      ← GovernanceGate.evaluatePostExecution() (Fail-Closed)
 *    ↓
 *   [Ledger Recording]      ← ResearchLedger.append()
 *    ↓
 *   Paper (view)            ← PaperRenderer.render()
 *
 * Fail-Closed: any gate failure sets status='BLOCKED' and prevents advancement.
 * No silent assumptions: all required fields must be present at each stage.
 */

import type {
  ResearchIntent,
  FormalizedHypothesis,
  ExperimentSpec,
  ExperimentResult,
  ResearchState,
  GovernanceViolation,
} from '../types/rgo';
import { ResearchCompiler } from './ResearchCompiler';
import { GovernanceGate } from './GovernanceGate';
import { ResearchLedger } from './ResearchLedger';
import { PaperRenderer } from './PaperRenderer';

function generateResearchId(): string {
  return `research_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

export class ResearchPipeline {
  private states: Map<string, ResearchState> = new Map();

  private compiler = new ResearchCompiler();
  private gate = new GovernanceGate();
  private ledger = new ResearchLedger();
  private renderer = new PaperRenderer();

  // ---------------------------------------------------------------------------
  // Phase ①: Intent Structuring
  // ---------------------------------------------------------------------------

  /**
   * Begin a new research project by submitting a structured intent.
   * Returns the initial ResearchState, or throws GovernanceViolations if invalid.
   */
  submitIntent(input: Partial<ResearchIntent>): ResearchState {
    const result = this.compiler.buildIntent(input);

    if (Array.isArray(result)) {
      throw this.buildViolationError('Intent validation failed', result);
    }

    const intent = result;
    const researchId = generateResearchId();
    const now = new Date().toISOString();

    const ledgerEntry = this.ledger.append(researchId, 'INTENT', {
      intentId: intent.intentId,
      problemStatement: intent.problemStatement,
      importance: intent.importance,
      keywords: intent.keywords,
    });

    const state: ResearchState = {
      researchId,
      currentPhase: 'FORMALIZATION',
      status: 'IN_PROGRESS',
      intent,
      gateResults: [],
      ledgerEntries: [ledgerEntry],
      startedAt: now,
      updatedAt: now,
    };

    this.states.set(researchId, state);
    return state;
  }

  // ---------------------------------------------------------------------------
  // Phase ②: Formalization
  // ---------------------------------------------------------------------------

  /**
   * Attach a formalized hypothesis to an existing research project.
   * The hypothesis is compiled and validated; failures throw GovernanceViolations.
   */
  formalize(
    researchId: string,
    hypothesisInput: Partial<FormalizedHypothesis>
  ): ResearchState {
    const state = this.requireState(researchId, 'FORMALIZATION');

    const result = this.compiler.compile(state.intent!, hypothesisInput);

    if (Array.isArray(result)) {
      throw this.buildViolationError('Hypothesis formalization failed', result);
    }

    const hypothesis = result;
    const ledgerEntry = this.ledger.append(researchId, 'FORMALIZATION', {
      hypothesisId: hypothesis.hypothesisId,
      statement: hypothesis.statement,
      nullHypothesis: hypothesis.nullHypothesis,
      metricCount: hypothesis.metrics.length,
      constraintCount: hypothesis.constraints.length,
      causalModel: hypothesis.causalModel ?? null,
    });

    const nextState = this.mergeState(state, {
      currentPhase: 'GOVERNANCE_GATE_1',
      hypothesis,
      ledgerEntries: [...state.ledgerEntries, ledgerEntry],
    });

    this.states.set(researchId, nextState);
    return nextState;
  }

  // ---------------------------------------------------------------------------
  // Phase ③④: Governance Gate① → Execution → Governance Gate②
  // ---------------------------------------------------------------------------

  /**
   * Submit an experiment specification and its result.
   * Automatically runs Gate① (pre-execution) and Gate② (post-execution).
   *
   * If either gate FAILS, the research is BLOCKED and the paper cannot be rendered.
   */
  submitExperiment(
    researchId: string,
    spec: ExperimentSpec,
    result: ExperimentResult
  ): ResearchState {
    let state = this.requireState(researchId, 'GOVERNANCE_GATE_1');

    // --- Gate① (PRE_EXECUTION) ---
    const gate1Result = this.gate.evaluatePreExecution(state.hypothesis!);
    const gate1LedgerEntry = this.ledger.append(researchId, 'GOVERNANCE_GATE_1', {
      gateId: gate1Result.gateId,
      status: gate1Result.status,
      violationCount: gate1Result.violations.length,
    });

    state = this.mergeState(state, {
      gateResults: [...state.gateResults, gate1Result],
      ledgerEntries: [...state.ledgerEntries, gate1LedgerEntry],
    });

    if (gate1Result.status === 'FAIL') {
      const blockedState = this.mergeState(state, {
        currentPhase: 'GOVERNANCE_GATE_1',
        status: 'BLOCKED',
        experimentSpec: spec,
      });
      this.states.set(researchId, blockedState);
      return blockedState;
    }

    // --- Execution Phase ---
    const execLedgerEntry = this.ledger.append(researchId, 'EXECUTION', {
      experimentId: spec.experimentId,
      hypothesisId: spec.hypothesisId,
      procedureStepCount: spec.procedure.length,
      randomSeed: spec.randomSeed ?? null,
      reproducibilityHash: result.reproducibilityHash,
    });

    state = this.mergeState(state, {
      currentPhase: 'GOVERNANCE_GATE_2',
      experimentSpec: spec,
      experimentResult: result,
      ledgerEntries: [...state.ledgerEntries, execLedgerEntry],
    });

    // --- Gate② (POST_EXECUTION) ---
    const gate2Result = this.gate.evaluatePostExecution(state.hypothesis!, spec, result);
    const gate2LedgerEntry = this.ledger.append(researchId, 'GOVERNANCE_GATE_2', {
      gateId: gate2Result.gateId,
      status: gate2Result.status,
      violationCount: gate2Result.violations.length,
    });

    state = this.mergeState(state, {
      gateResults: [...state.gateResults, gate2Result],
      ledgerEntries: [...state.ledgerEntries, gate2LedgerEntry],
    });

    if (gate2Result.status === 'FAIL') {
      const blockedState = this.mergeState(state, {
        currentPhase: 'GOVERNANCE_GATE_2',
        status: 'BLOCKED',
      });
      this.states.set(researchId, blockedState);
      return blockedState;
    }

    // --- Ledger Recording Phase ---
    const ledgerEntry = this.ledger.append(researchId, 'LEDGER', {
      message: 'Research passed all governance gates. Advancing to PAPER phase.',
      totalGates: state.gateResults.length + 1,
    });

    const completedState = this.mergeState(state, {
      currentPhase: 'PAPER',
      status: 'COMPLETED',
      ledgerEntries: [...state.ledgerEntries, ledgerEntry],
    });

    this.states.set(researchId, completedState);
    return completedState;
  }

  // ---------------------------------------------------------------------------
  // Phase ⑤: Paper (view of Ledger)
  // ---------------------------------------------------------------------------

  /**
   * Render a Markdown paper for a completed research project.
   * Throws if the research is not COMPLETED.
   */
  renderPaper(researchId: string): string {
    const state = this.requireStateAny(researchId);
    return this.renderer.render(state);
  }

  // ---------------------------------------------------------------------------
  // Ledger operations
  // ---------------------------------------------------------------------------

  /**
   * Verify the integrity of the entire ledger chain.
   */
  verifyLedgerIntegrity(): boolean {
    return this.ledger.verifyIntegrity();
  }

  // ---------------------------------------------------------------------------
  // State inspection
  // ---------------------------------------------------------------------------

  getState(researchId: string): ResearchState {
    return this.requireStateAny(researchId);
  }

  listResearchIds(): string[] {
    return Array.from(this.states.keys());
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private requireState(researchId: string, expectedPhase: ResearchState['currentPhase']): ResearchState {
    const state = this.states.get(researchId);
    if (!state) {
      throw new Error(`[RGO] Research "${researchId}" not found.`);
    }
    if (state.currentPhase !== expectedPhase) {
      throw new Error(
        `[RGO] Research "${researchId}" is in phase "${state.currentPhase}", ` +
        `but "${expectedPhase}" is required.`
      );
    }
    return state;
  }

  private requireStateAny(researchId: string): ResearchState {
    const state = this.states.get(researchId);
    if (!state) {
      throw new Error(`[RGO] Research "${researchId}" not found.`);
    }
    return state;
  }

  private mergeState(
    state: ResearchState,
    updates: Partial<ResearchState>
  ): ResearchState {
    return {
      ...state,
      ...updates,
      updatedAt: new Date().toISOString(),
    };
  }

  private buildViolationError(
    context: string,
    violations: GovernanceViolation[]
  ): Error {
    const details = violations
      .map(v => `  [${v.code}] ${v.message}${v.path ? ` (path: ${v.path})` : ''}`)
      .join('\n');
    return new Error(`[RGO] ${context}:\n${details}`);
  }
}
