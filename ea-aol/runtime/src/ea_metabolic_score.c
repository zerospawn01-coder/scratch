#include "ea_metabolic.h"
#include <math.h>
#include <stddef.h>

#define ERR_MAX_THRESHOLD 0.3f
#define EPSILON 1e-6f

void ea_metabolic_update_scores(ea_metabolic_context_t *ctx,
                                ea_power_state_t pwr_state) {
  if (ctx == NULL || ctx->experts == NULL)
    return;

  float sum_q = 0.0f, sum_e = 0.0f;
  float w_q, w_e;

  /* Jules Policy Table */
  switch (pwr_state) {
  case EA_POWER_GRID_STABLE:
    w_q = 1.0f;
    w_e = 0.1f;
    break;
  case EA_POWER_GRID_CONSTRAINED:
    w_q = 0.7f;
    w_e = 0.5f;
    break;
  case EA_POWER_BATTERY:
    w_q = 0.3f;
    w_e = 1.0f;
    break;
  case EA_POWER_CRITICAL:
    w_q = 0.0f;
    w_e = 1.0f;
    break;
  default:
    w_q = 0.5f;
    w_e = 1.0f;
    break;
  }

  /* Step B: Multi-pass normalization to ensure precision guard (Jules Style) */
  for (uint32_t i = 0; i < ctx->total_experts; i++) {
    sum_q += ctx->experts[i].impact_score;
    sum_e += ctx->experts[i].energy_delta_ema;
  }

  if (sum_e < EPSILON)
    sum_e = EPSILON; // Prevent division by zero

  /* Step C: Core Calculation with Hard Floor Security */
  for (uint32_t i = 0; i < ctx->total_experts; i++) {
    ea_expert_meta_t *e = &ctx->experts[i];
    float score = 0.0f;

    float norm_q = (sum_q > 0) ? (e->impact_score / sum_q) : 0;
    float norm_e = (e->energy_delta_ema / sum_e);

    if (pwr_state == EA_POWER_CRITICAL) {
      /* Survival Filtering Mode */
      if (e->error_rate < ERR_MAX_THRESHOLD) {
        score = 1.0f / (norm_e + EPSILON);
        score *= (1.0f - e->error_rate);
      } else {
        score = 0.0f; // Eliminate zombies
      }
    } else {
      /* Metabolic Scaling Mode */
      score = (w_q * norm_q) / (w_e * norm_e + EPSILON);
      score *= (1.0f - e->error_rate);
    }
    e->survivability_score = score;
  }
}
