/**
 * EA-AOL Audit & Prosecution Logger v0.3
 */
#ifndef EA_AUDIT_H
#define EA_AUDIT_H

#include "ea_hal_power.h"
#include "ea_metabolic.h"
#include <stdbool.h>
#include <stdint.h>


typedef enum {
  EA_DEATH_NONE = 0,
  EA_DEATH_ERROR_RATE = (1 << 0),
  EA_DEATH_ENERGY_DOMINATED = (1 << 1),
  EA_DEATH_QUALITY_INSUFFICIENT = (1 << 2),
  EA_DEATH_DEPENDENCY_FAILURE = (1 << 3),
  EA_DEATH_POLICY_THRESHOLD = (1 << 4)
} ea_death_cause_t;

typedef struct {
  uint64_t timestamp_ns;
  uint32_t expert_id;
  uint32_t pwr_state;
  float norm_q;
  float norm_e;
  float w_q;
  float w_e;
  float final_score;
  uint32_t rank;
  uint32_t death_cause_mask;
  uint32_t counterfactual_grid_rank;
  uint8_t decision; /* 1=ALIVE, 0=DEAD */
  uint8_t _padding[3];
} ea_audit_record_t;

#define EA_AUDIT_RING_SIZE 1024

typedef struct {
  ea_audit_record_t records[EA_AUDIT_RING_SIZE];
  uint32_t head;
  bool dirty;
  int fd;
  ea_power_state_t last_flushed_pwr_state;
} ea_audit_buffer_t;

int ea_audit_init(const char *log_file);
void ea_audit_log_decision(const ea_audit_record_t *record);
void ea_audit_flush(void);
void ea_audit_close(void);

#endif
