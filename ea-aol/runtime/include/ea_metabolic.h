/**
 * EA-AOL Metabolic & Survivability Model v0.3
 */
#ifndef EA_METABOLIC_H
#define EA_METABOLIC_H

#include "ea_hal_power.h"
#include <stdbool.h>
#include <stdint.h>


/**
 * Expert Metadata
 */
typedef struct {
  uint32_t expert_id;
  float energy_delta_avg;
  float energy_delta_ema;
  float quality_contribution;
  float impact_score;
  float error_rate;
  float variance;
  uint64_t dependency_mask;
  uint32_t co_occurrence_low;
  float survivability_score;
  bool is_active;
  bool _next_state; /* Internal: Two-phase commit decision */
} ea_expert_meta_t;

typedef struct {
  uint32_t total_experts;
  ea_expert_meta_t *experts;
  float global_energy_target;
  uint32_t active_count;
} ea_metabolic_context_t;

/* Score Calculation and Policy Execution */
void ea_metabolic_update_scores(ea_metabolic_context_t *ctx,
                                ea_power_state_t pwr_state);
void ea_metabolic_execute_policy(ea_metabolic_context_t *ctx,
                                 ea_power_state_t pwr_state);

#endif
