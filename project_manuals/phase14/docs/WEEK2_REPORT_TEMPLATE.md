# Week2 Report Template

**Purpose:** Standard 5-section weekly report generated end-of-Friday (Fri PM).

**Frequency:** Every Friday (Weeks 2–4)  
**Owner:** Operations Manager  
**Audience:** Phase14-A governance, phase leads, stakeholders

---

## Template (Fill In Friday Afternoon)

```markdown
# Phase14-A Operations Report
## Week X (YYYYMMDD–YYYYMMDD)

### Section 1: Discovery Run Summary

**Date:** Monday, YYYYMMDD  
**Time Elapsed:** ___ minutes  
**Status:** ☐ SUCCESS ☐ FAILED

**Inputs:** 
- Cases extracted: ___
- Date range: [start_ts to end_ts]

**Outputs:**
- Canonical cases: ___
- Embedding vectors: ___
- Clustering algorithm: HDBSCAN v1
- Clustering exit code: 0

**Notes:** [Any anomalies or delays during discovery]

---

### Section 2: Clustering Snapshot

**File:** `phase14/outputs/snapshots/clustering_YYYYMMDD.json`

| Metric | Value | Expected Range | Status |
|--------|-------|-----------------|--------|
| total_cases | ___ | — | ☐ ✓ |
| clustered_cases | ___ | >80% of total | ☐ ✓ |
| noise_cases | ___ | <20% of total | ☐ ✓ |
| cluster_count | ___ | 10–30 (advisory) | ☐ ✓ |
| median_cluster_size | ___ | — | ☐ ✓ |
| run_id | ___ | UUID | ☐ ✓ |
| clustering_version | hdbscan_v1 | hdbscan_v1 | ☐ ✓ |

**Narrative:** [Describe clustering quality; note any unusual distributions]

---

### Section 3: Candidate Generation Statistics

**File:** `phase14/data/processed/YYYYMMDD_candidates.jsonl`

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Candidates Generated** | ___ | <100 | ☐ NORMAL ☐ ELEVATED |
| **Avg Support** | ___ | ≥ 10 | ☐ ✓ |
| **Avg Confidence** | ___ | ≥ 0.85 | ☐ ✓ |
| **Avg Lift** | ___ | ≥ 1.20 | ☐ ✓ |
| **Avg Override Rate** | ___ | ≤ 0.05 | ☐ ✓ |
| **Avg Fallback Rate** | ___ | ≤ 0.10 | ☐ ✓ |

**Priority Score Range:** ___ to ___ (min to max)

**Risk Assessment:**
- ☐ Candidate explosion: NO (count <100)
- ☐ Candidate explosion: TRIGGERED (count ≥100, actions: _______)

**Sample Top 3 Candidates (by priority):**
1. Candidate A: support=___, confidence=___, lift=___, score=___
2. Candidate B: support=___, confidence=___, lift=___, score=___
3. Candidate C: support=___, confidence=___, lift=___, score=___

**Narrative:** [Comment on candidate quality, distribution of scores, any concern patterns]

---

### Section 4: Review Throughput Metrics

**Period:** Tuesday–Wednesday review sessions  
**File:** `phase14/data/review/decisions_YYYYMMDD.jsonl`

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Candidates Submitted for Review** | ___ | — | — |
| **Candidates Reviewed (APPROVED)** | ___ | — | ☐ ✓ |
| **Candidates Reviewed (REJECTED)** | ___ | — | ☐ ✓ |
| **Total Candidates Reviewed** | ___ | 40–50 | ☐ ✓ |
| **Review Duration** | ___ hours | — | ☐ ✓ |
| **Throughput (candidates/hour)** | ___ | ≥ 80 | ☐ NORMAL ☐ ELEVATED ☐ CRITICAL |
| **Avg Decision Time** | ___ sec | ≤ 30 | ☐ ✓ ☐ ✗ |
| **Approval Rate** | __% | 50–70% | ☐ ✓ |

**Reviewers Participating:** _____, _____

**Decision Distribution:**
- Total APPROVE: ___
- Total REJECT: ___
- Rejection rate: ___%

**Risk Assessment:**
- ☐ Review fatigue: NO (throughput >60 cand/hr)
- ☐ Review fatigue: ELEVATED (throughput 40–60; actions: _______)
- ☐ Review fatigue: CRITICAL (throughput <40; escalation: _______)

**Sample Rejection Reasons (if any):**
- Low confidence: ___
- Insufficient support: ___
- High override rate: ___
- [Other]: ___

**Narrative:** [Comment on reviewer consistency, decision quality, any friction points]

---

### Section 5: Promotion Decisions & Matrix Update

**Date:** Thursday promotion gate  
**Files:** `matrix_change_YYYYMMDD.jsonl`, `rejected_changes_YYYYMMDD.jsonl`

| Metric | Value | Status |
|--------|-------|--------|
| **Rules Submitted to Gate** | ___ (approved rules) | ☐ ✓ |
| **Rules Approved at Gate** | ___ | ☐ ✓ |
| **Rules Rejected at Gate** | ___ | ☐ ✓ |
| **Gate Approval Rate** | __% | ☐ NORMAL ☐ ELEVATED |
| **Conflict Instances** | ___ | ☐ NONE ☐ RESOLVED ☐ ESCALATED |
| **Matrix Before Hash** | ________________ | — |
| **Matrix After Hash** | ________________ | — |

**Rejection Reasons (at gate):**
- Reviewer consensus insufficient: ___
- Confidence threshold not met: ___
- Override rate too high: ___
- Conflict with existing rule: ___
- Policy violation: ___

**Conflict Resolution (if any):**
- Conflicts detected: ___
- Resolved by rejection: ___
- Resolved by manual override (HLG approved): ___
- Unresolved: ___ (requires escalation)

**Risk Assessment:**
- ☐ Promotion bottleneck: NO (<30% rejection)
- ☐ Promotion bottleneck: ELEVATED (30–50% rejection; audit: _______)
- ☐ Promotion bottleneck: CRITICAL (>50% rejection; escalation: _______)

**Narrative:** [Describe gate health, any systematic failures, patterns in rejections]

---

### Section 6: A/B Test Evaluation

**Date:** Friday afternoon A/B test run  
**File:** `phase14/outputs/reports/ab_test_YYYYMMDD.json`

**Baseline (Week1):** [cite from WEEK1_EXIT_GATE.md or previous report]

| Metric | Week1 Baseline | WeekX (This Week) | Δ | Status |
|--------|---|---|---|---|
| `selection_accuracy` | __% | __% | Δ __pp | ☐ ✓ ↑ ☐ ✗ ↓ |
| `fallback_rate` | __% | __% | Δ __pp | ☐ ✓ ↓ ☐ ✗ ↑ |
| `latency_ms` | ___ | ___ | Δ ___ms | ☐ ✓ <+10% ☐ ✗ |
| `human_override_rate` | __% | __% | Δ __pp | ☐ TARGET: <5% |

**Week-over-Week Trend (if multiple weeks):**

| Metric | Week2 | Week3 | Week4 | Trend |
|--------|-------|-------|-------|-------|
| selection_accuracy | __% | __% | __% | ☐ ↑ stable ☐ ↓ |
| fallback_rate | __% | __% | __% | ☐ ↓ stable ☐ ↑ |
| latency_ms | ___ | ___ | ___ | ☐ stable ☐ increasing |

**Interpretation:** [Explain whether metrics are improving, stable, or degrading. Address each metric.]

---

### Section 7: Weekly Governance Review (Bias + Drift + Promotion)

**Command:**

```bash
python phase14/scripts/aggregate_weekly_governance_report.py --week-label YYYYMMDD --start-date YYYYMMDD --end-date YYYYMMDD --drift-date YYYYMMDD --promotion-date YYYYMMDD
```

**Files:**
- `phase14/outputs/reports/weekly_governance_report_YYYYMMDD.json`
- `phase14/outputs/reports/weekly_governance_report_YYYYMMDD.md`

| Domain | Metric | Value | Threshold | Status |
|--------|--------|-------|-----------|--------|
| Bias | `team_mean_accuracy` | ___ | ≥ 0.80 | ☐ ✓ ☐ ✗ |
| Bias | `team_mean_agreement` | ___ | ≥ 0.80 | ☐ ✓ ☐ ✗ |
| Bias | `high_risk_reviewers_count` | ___ | 0 preferred | ☐ ✓ ☐ ✗ |
| Drift | `rule_drift_rate` | ___ | ≤ 0.05 | ☐ ✓ ☐ ✗ |
| Promotion | `rejection_rate` | ___ | ≤ 0.30 | ☐ ✓ ☐ ✗ |
| Promotion | `novel_case_ratio` | ___ | ≤ 0.15 | ☐ ✓ ☐ ✗ |

**Promotion Diagnostics:**
- `rejection_reason_distribution`: [top reasons and counts]
- `novel_case_ratio`: `NOVEL_CASE_REQUIRES_HLG / total_rejections`

**Required Actions:** [From report `required_actions` list]
- ______

**Narrative:** [One paragraph: whether governance loop is stable or requires intervention]

---

## Summary & Next Week Plan

**Overall Status (Select One):**
- ✅ **ON TRACK:** All metrics healthy, no risks triggered
- ⚠️  **CAUTION:** 1–2 metrics trending concerning, 1 risk elevated (being monitored)
- 🚨 **INTERVENTION:** 2+ risks triggered, actions in progress

**Key Accomplishments This Week:**
- ______
- ______
- ______

**Issues & Resolutions:**
- [Issue]: [Resolution taken or planned]
- [Issue]: [Resolution taken or planned]

**Next Week Plan (Mon kickoff):**
- Discovery run time: Mon ___:___ AM
- Review sessions: Tue/Wed ___:___ AM–PM
- Promotion gate: Thu ___:___ AM
- Evaluation: Fri ___:___ PM

**Metrics to Watch Next Week:**
- ☐ Candidate count (watch for explosion >100)
- ☐ Review throughput (watch for fatigue <60/hr)
- ☐ Gate rejection rate (watch for bottleneck >30%)

**Escalations Required:** ☐ NO ☐ YES — [describe]

---

## Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Operations Manager | _______ | _____ | _______ |
| Governance Owner | _______ | _____ | _______ |
| Tech Lead | _______ | _____ | _______ |

---

**Report Generated:** Friday, YYYYMMDD, __:__ PM  
**Report Version:** v1.0  
**Next Report Due:** Friday, [next week's date]
```

---

## Example Completed Report (Week2)

[See companion file: WEEK2_REPORT_EXAMPLE.md (optional, for reference)]

---

## Checklist: Before Submitting Report

- [ ] All 6 sections completed with actual numbers
- [ ] All metric thresholds checked (☐ marks visible)
- [ ] Risk assessments filled (NORMAL / ELEVATED / CRITICAL)
- [ ] Narrative sections explain numbers (not just data dumps)
- [ ] Week-over-week trends included (if Week 3+)
- [ ] Next week plan explicit and scheduled
- [ ] All three sign-off roles completed
- [ ] Report filed in `phase14/outputs/reports/weekly_report_YYYYMMDD.md`
- [ ] Slack notification sent to stakeholders

---

## Notes

- **Brevity:** Keep narrative sections to 2–4 sentences per metric
- **Clarity:** Use ☐ marks and ↑/↓ symbols for quick visual scanning
- **Timeliness:** Complete by Fri 6 PM so stakeholders see it over weekend
- **Trend:** If reporting Weeks 3–4, always include week-over-week comparison

---

**Version:** v1.0 | **Date:** 2026-03-08 | **Template Ready for Week2 Launch**
