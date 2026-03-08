# Week2 Operational Kickoff (30-Min One-Pager)

Date: YYYY-MM-DD  
Owner: Governance Owner  
Attendees: Engineering Lead, Governance Owner, Ledger Lead, Product Owner, Reviewers

## Objective

Start Week2 operations with one aligned rule for review decisions and one aligned operating cadence.

Core rule:
- Approve only when statistical support and governance checks are sufficient.
- Otherwise reject with explicit reason (fail-closed).

## Pre-Read (5 min before meeting)

- `phase14/docs/PHASE14B_READINESS_GATE.md`
- `phase14/docs/WEEK2_REPORT_TEMPLATE.md`
- Latest clustering and mining outputs for kickoff date

## 30-Min Agenda

1. 0:00-0:05 | Opening and success criteria
- Confirm Week2 target outcomes: throughput, override rate, candidate stability.

2. 0:05-0:10 | Operational flow lock
- Confirm fixed flow:
  `Discovery -> Candidate Generation -> Human Review -> Promotion Gate -> Weekly Governance`.
- Confirm Mon-Tue-Wed-Thu-Fri cadence and owners.

3. 0:10-0:18 | Review policy alignment
- Confirm binary review policy:
  `APPROVE` or `REJECT` only.
- Confirm reject reasons are mandatory and taxonomy-mapped.
- Confirm novel cases escalate to HLG (fail-closed).

4. 0:18-0:26 | Review example calibration (2 cases)
- Walk through two examples below and force explicit rationale.
- Record disagreements and finalize tie-break rule.

5. 0:26-0:30 | Decision and kickoff actions
- Confirm go/no-go for Week2 run.
- Assign Monday discovery time, Tue/Wed review sessions, Thu promotion gate, Fri governance review.

## Review Example Templates (Use in meeting)

### Example A (Expected APPROVE)

- Candidate ID:
- Proposed Rule:
- Evidence:
  - support:
  - confidence:
  - lift:
  - override_rate_impact:
  - fallback_rate_impact:
- Governance checks:
  - conflict check:
  - taxonomy coverage:
  - drift risk:
- Reviewer decision: APPROVE / REJECT
- Rationale (1-3 lines):

### Example B (Expected REJECT)

- Candidate ID:
- Proposed Rule:
- Evidence:
  - support:
  - confidence:
  - lift:
  - override_rate_impact:
  - fallback_rate_impact:
- Governance checks:
  - conflict check:
  - taxonomy coverage:
  - drift risk:
- Reviewer decision: APPROVE / REJECT
- Rejection reason class:
  - `POLICY_CONFLICT_DENY_DEFAULT`
  - `MANUAL_OVERRIDE_REQUIRED`
  - `NOVEL_CASE_REQUIRES_HLG`
- Rationale (1-3 lines):

## Required Outputs (End of Meeting)

- Kickoff decision: `GO` or `HOLD`
- Week2 schedule locked (Mon-Fri timestamps)
- Reviewer calibration notes saved
- Owners confirmed for:
  - discovery run
  - review queue moderation
  - promotion gate
  - Friday governance report

## Sign-Off

- Engineering Lead:
- Governance Owner:
- Ledger Lead:
- Product Owner:
