# Hardening Report & Submission Narrative

## 1. Adversarial Patch Replay Results

The core state logic was stress-tested against four network failure scenarios to ensure "Physical Irreversibility" and state consistency.

### Hardening Evidence Table (Clean-Room Verified)

| Test Case | Scenario | Core Match? | Rejected | Quarantined | Result |
|-----------|----------|-------------|----------|-------------|--------|
| **REPLAY_A** | Baseline (Strict Order) | **YES** | 0 | 0 | **PASS** |
| **REPLAY_B** | Network Jitter (Shuffled) | **YES** | 45 | 0 | **PASS** |
| **REPLAY_C** | Idempotency (Duplicates) | **YES** | 20 | 0 | **PASS** |
| **REPLAY_D** | Mixed RunID Injection | **NO_MUTATE**| 0 | 1 | **BOOT_ISOLATED** |

**Quantitative Telemetry Summary:**

- **Reorder Rejections (Test B):** 45
- **Duplicate Rejections (Test C):** 20
- **Quarantine Detections (Test D):** 1

> [!NOTE]
> Replay B and C rejections are intentional: the system drops patches that arrive with a `seq` less than or equal to the currently processed `lastSeq`, ensuring the state never "rolls back" out of order.

---

# 🔥 Devpost Submission: Live Agents — The Accountable Incident Copilot

### Elevator Pitch

Live Agents is an accountable AI co-pilot for incident response that transforms real-time Gemini insights into controlled, auditable recovery actions — even in noisy, high-stakes production environments. It replaces unsafe AI “autopilot” patterns with deterministic mediation, human gating, and mathematically enforced state integrity.

---

## The Problem: The Fog of War

During major outages, SREs operate in chaotic conditions where:
- Standard voice NLP fails in **deafening data centers**
- Black-box AI automation is too risky to trust
- Incident timelines are compressed and error budgets evaporate
- Voice-only interfaces entirely exclude engineers with vocal impairments (e.g., ALS) from operational roles

In critical infrastructure, a hallucinated command or unauthorized execution is catastrophic.

---

## The Solution: Deterministic Mediation

Powered by the **Gemini Multimodal Live API**, Live Agents extracts **continuous, real-time, interruptible intent** through:
- A noise-resilient Special Voice Protocol (SVP)
- Silent lip-based command classification (MediaPipe FaceMesh)
- Visual context shared with the model

Intent is never executed directly. Instead, every action flows through a **Causal Gate** enforced by:
- Deterministic patch sequencing
- Tool-verified “ARMED” staging
- Two-factor human approval
- Immutable audit logging

The backend runs on **Google Cloud Run**, with state events recorded via **Cloud Logging**, ensuring production-grade traceability.

---

## Architectural Invariants (Technical Execution)

**Monotonic Sequencing**
Custom patch protocol rejects out-of-order, duplicate, and cross-run injections. Replays converge to an identical final WorldState.

**Causal Gating (Cloud IAM-Aligned)**
Execution is physically blocked until tool verification and staged approval succeed. No free-text execution.

**Fail-Closed Isolation**
Schema mismatches or unauthorized RunIDs trigger audited `SAFE_MODE_ISOLATED` state. The system degrades safely.

**Dual-View Situational Awareness**
2D causal topology for logical tracing and a 3D spatial twin (React Three Fiber) for blast-radius cognition — dynamically driven via Gemini function calling.

---

## Why It Wins

Live Agents proves that multimodal AI can operate inside critical infrastructure without sacrificing safety. It expands operational accessibility (lip-based Silent Mode), survives adversarial network conditions, enforces human mediation, and produces auditable, deterministic state transitions.

This is not AI as a chatbot. It is AI as an accountable operational layer.

---

> *“The agent is incapable of executing outside a deterministic, audited, two-factor-gated action path; all failures degrade to safe-mode with explicit operator visibility.”*
