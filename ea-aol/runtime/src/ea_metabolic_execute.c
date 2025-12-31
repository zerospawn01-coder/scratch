#include "ea_audit.h"
#include "ea_metabolic.h"
#include <stdlib.h>
#include <time.h>


/* Sort descending by Survivability Score */
static int _compare_experts(const void *a, const void *b) {
  const ea_expert_meta_t *ea = *(const ea_expert_meta_t **)a;
  const ea_expert_meta_t *eb = *(const ea_expert_meta_t **)b;
  if (ea->survivability_score > eb->survivability_score)
    return -1;
  if (ea->survivability_score < eb->survivability_score)
    return 1;
  return 0;
}

void ea_metabolic_execute_policy(ea_metabolic_context_t *ctx,
                                 ea_power_state_t pwr_state) {
  if (ctx == NULL || ctx->experts == NULL)
    return;

  /* Phase 0: Ranking */
  ea_expert_meta_t *sorted[64];
  uint32_t total = (ctx->total_experts > 64) ? 64 : ctx->total_experts;

  for (uint32_t i = 0; i < total; i++) {
    sorted[i] = &ctx->experts[i];
  }

  qsort(sorted, total, sizeof(ea_expert_meta_t *), _compare_experts);

  /* Phase 1: Judgment & Audit (Sequential) */
  uint32_t survival_quota;
  switch (pwr_state) {
  case EA_POWER_GRID_STABLE:
    survival_quota = total;
    break;
  case EA_POWER_GRID_CONSTRAINED:
    survival_quota = (uint32_t)(total * 0.8);
    break;
  case EA_POWER_BATTERY:
    survival_quota = (uint32_t)(total * 0.5);
    break;
  case EA_POWER_CRITICAL:
    survival_quota = 1;
    break;
  default:
    survival_quota = 1;
    break;
  }

  for (uint32_t r = 0; r < total; r++) {
    ea_expert_meta_t *e = sorted[r];
    ea_audit_record_t record = {0};

    record.timestamp_ns = (uint64_t)time(NULL);
    record.expert_id = e->expert_id;
    record.pwr_state = (uint32_t)pwr_state;
    record.final_score = e->survivability_score;
    record.rank = r + 1;

    if (r < survival_quota) {
      record.decision = 1; // ALIVE
      record.death_cause_mask = EA_DEATH_NONE;
    } else {
      record.decision = 0; // DEAD
      record.death_cause_mask = EA_DEATH_POLICY_THRESHOLD;
      if (e->error_rate > 0.3f)
        record.death_cause_mask |= EA_DEATH_ERROR_RATE;
    }

    ea_audit_log_decision(&record);
    e->_next_state = (record.decision == 1);
  }

  /* Phase 2: Atomic Execution */
  ctx->active_count = 0;
  for (uint32_t i = 0; i < total; i++) {
    ctx->experts[i].is_active = ctx->experts[i]._next_state;
    if (ctx->experts[i].is_active)
      ctx->active_count++;
  }

  /* Jules: Ensure historical record is immutable on disk after metabolic shift
   */
  ea_audit_flush();
}
