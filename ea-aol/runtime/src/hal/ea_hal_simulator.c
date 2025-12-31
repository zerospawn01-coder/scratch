/*
 * ea_hal_simulator.c - Physics Simulator for Integration Testing
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 *
 * This is a virtual physics lab that simulates how hardware responds
 * to control commands. It implements realistic power/performance models
 * based on frequency and MoE Top-K settings.
 *
 * Physics Models:
 * - Power = Idle + (Load × MaxDynamic × FreqRatio × KRatio)
 * - Throughput = Base × FreqRatio × sqrt(MaxK / CurrentK)
 * - Temperature = 40 + (Power / 5)
 */

#include "ea_hal.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>


/* ============================================================================
 * Physics Constants
 * ========================================================================= */

#define SIM_MAX_FREQ_MHZ 2000.0
#define SIM_MIN_FREQ_MHZ 200.0
#define SIM_MAX_K 8
#define SIM_MIN_K 1

/* Power model constants */
#define SIM_IDLE_POWER_W 50.0
#define SIM_MAX_LOAD_POWER_W 250.0

/* Throughput model constants */
#define SIM_BASE_TPS 40.0

/* Temperature model constants */
#define SIM_BASE_TEMP_C 40.0
#define SIM_TEMP_POWER_RATIO 5.0

/* Load simulation */
#define SIM_LOAD_MIN 0.2
#define SIM_LOAD_MAX 1.0
#define SIM_LOAD_NOISE 0.1

/* ============================================================================
 * Simulator State
 * ========================================================================= */

typedef struct {
  /* Current hardware state */
  double current_freq_mhz;
  int current_top_k;
  double current_power_limit_w;

  /* Simulated environment */
  double simulated_load; /**< Traffic load [0.2, 1.0] */
  double load_trend;     /**< Load change trend */

  /* Derived metrics */
  double current_power_w;
  double current_temp_c;
  double current_throughput_tps;
  double current_util;

  /* Timing */
  uint64_t last_update_ms;

  /* Device info */
  int device_index;
  bool initialized;
} sim_context_t;

/* ============================================================================
 * Helper Functions
 * ========================================================================= */

static uint64_t get_time_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static double clamp(double value, double min, double max) {
  if (value < min)
    return min;
  if (value > max)
    return max;
  return value;
}

/* ============================================================================
 * Physics Simulation
 * ========================================================================= */

static void simulate_load_change(sim_context_t *ctx) {
  /* Random walk with trend */
  double noise = ((rand() % 100) / 100.0 - 0.5) * SIM_LOAD_NOISE;

  /* Occasionally spike the load (10% chance) */
  if (rand() % 100 < 10) {
    ctx->load_trend = 0.3; /* Spike upward */
    printf("[Simulator] 🔥 Load spike triggered!\n");
  } else if (rand() % 100 < 5) {
    ctx->load_trend = -0.2; /* Drop */
  }

  /* Apply trend and noise */
  ctx->simulated_load += ctx->load_trend + noise;

  /* Decay trend */
  ctx->load_trend *= 0.9;

  /* Clamp to valid range */
  ctx->simulated_load = clamp(ctx->simulated_load, SIM_LOAD_MIN, SIM_LOAD_MAX);
}

static void calculate_physics(sim_context_t *ctx) {
  /* Calculate ratios */
  double freq_ratio = ctx->current_freq_mhz / SIM_MAX_FREQ_MHZ;
  double k_ratio = (double)ctx->current_top_k / SIM_MAX_K;

  /* Power Model: P = P_idle + P_load × Load × FreqRatio × KRatio
   *
   * Rationale:
   * - Higher frequency → more power
   * - More experts (higher k) → more computation → more power
   * - Higher load → more active computation → more power
   */
  double dynamic_power =
      SIM_MAX_LOAD_POWER_W * ctx->simulated_load * freq_ratio * k_ratio;
  ctx->current_power_w = SIM_IDLE_POWER_W + dynamic_power;

  /* Apply power limit if set */
  if (ctx->current_power_limit_w > 0 &&
      ctx->current_power_w > ctx->current_power_limit_w) {
    /* Simulate power capping (would reduce frequency in real hardware) */
    ctx->current_power_w = ctx->current_power_limit_w;
  }

  /* Throughput Model: TPS = Base × FreqRatio × sqrt(MaxK / CurrentK)
   *
   * Rationale:
   * - Higher frequency → more throughput
   * - Lower k → less computation per token → higher throughput
   * - sqrt factor: diminishing returns from k reduction
   */
  double k_speedup = sqrt((double)SIM_MAX_K / ctx->current_top_k);
  ctx->current_throughput_tps =
      SIM_BASE_TPS * freq_ratio * k_speedup * ctx->simulated_load;

  /* Temperature Model: Temp = Base + (Power / Ratio)
   *
   * Simplified thermal model with lag
   */
  ctx->current_temp_c =
      SIM_BASE_TEMP_C + (ctx->current_power_w / SIM_TEMP_POWER_RATIO);

  /* Utilization */
  ctx->current_util = ctx->simulated_load * 0.8; /* Simplified */

  printf("[Simulator] Physics: Freq=%.0f MHz, k=%d, Load=%.2f → Power=%.1f W, "
         "TPS=%.1f\n",
         ctx->current_freq_mhz, ctx->current_top_k, ctx->simulated_load,
         ctx->current_power_w, ctx->current_throughput_tps);
}

/* ============================================================================
 * Driver Implementation
 * ========================================================================= */

static int sim_init(void **ctx_out, int device_index) {
  printf("[Simulator] Initializing physics simulator for device %d\n",
         device_index);

  sim_context_t *ctx = (sim_context_t *)malloc(sizeof(sim_context_t));
  if (!ctx)
    return EA_HAL_ERR_NOT_INITIALIZED;

  memset(ctx, 0, sizeof(sim_context_t));

  /* Initialize to maximum performance state */
  ctx->current_freq_mhz = SIM_MAX_FREQ_MHZ;
  ctx->current_top_k = SIM_MAX_K;
  ctx->current_power_limit_w = 0; /* No limit */

  /* Start with moderate load */
  ctx->simulated_load = 0.5;
  ctx->load_trend = 0.0;

  ctx->device_index = device_index;
  ctx->initialized = true;
  ctx->last_update_ms = get_time_ms();

  /* Calculate initial physics */
  calculate_physics(ctx);

  *ctx_out = ctx;

  printf("[Simulator] Initialized: Freq=%.0f MHz, k=%d, Power=%.1f W\n",
         ctx->current_freq_mhz, ctx->current_top_k, ctx->current_power_w);

  return EA_HAL_OK;
}

static int sim_shutdown(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  printf("[Simulator] Shutting down\n");
  free(ctx);

  return EA_HAL_OK;
}

static int sim_get_telemetry(void *ctx, ea_telemetry_t *telemetry) {
  if (!ctx || !telemetry)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;
  if (!sim_ctx->initialized)
    return EA_HAL_ERR_NOT_INITIALIZED;

  /* Update simulation */
  uint64_t current_time = get_time_ms();
  uint64_t elapsed = current_time - sim_ctx->last_update_ms;

  /* Only update if enough time has passed (avoid too frequent updates) */
  if (elapsed > 100) { /* 100ms minimum */
    simulate_load_change(sim_ctx);
    calculate_physics(sim_ctx);
    sim_ctx->last_update_ms = current_time;
  }

  /* Fill telemetry */
  telemetry->power_w = sim_ctx->current_power_w;
  telemetry->temp_c = sim_ctx->current_temp_c;
  telemetry->utilization = sim_ctx->current_util;
  telemetry->freq_mhz = sim_ctx->current_freq_mhz;
  telemetry->timestamp_ms = current_time;

  return EA_HAL_OK;
}

static int sim_get_device_info(void *ctx, char *buffer, size_t buffer_size) {
  if (!ctx || !buffer)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  snprintf(buffer, buffer_size,
           "Physics Simulator (Device %d) - Virtual GPU with MoE support",
           sim_ctx->device_index);

  return EA_HAL_OK;
}

static int sim_set_power_limit(void *ctx, const ea_power_limit_t *limit) {
  if (!ctx || !limit)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  printf("[Simulator] Setting power limit: %.1f W\n", limit->limit_w);

  sim_ctx->current_power_limit_w = limit->limit_w;

  /* Recalculate physics */
  calculate_physics(sim_ctx);

  return EA_HAL_OK;
}

static int sim_set_frequency_range(void *ctx, const ea_freq_range_t *range) {
  if (!ctx || !range)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  /* Simulate instantaneous frequency change */
  double new_freq = (double)range->max_mhz;

  /* Clamp to valid range */
  new_freq = clamp(new_freq, SIM_MIN_FREQ_MHZ, SIM_MAX_FREQ_MHZ);

  printf("[Simulator] Frequency change: %.0f → %.0f MHz\n",
         sim_ctx->current_freq_mhz, new_freq);

  sim_ctx->current_freq_mhz = new_freq;

  /* Recalculate physics */
  calculate_physics(sim_ctx);

  return EA_HAL_OK;
}

static int sim_set_cooling(void *ctx, const ea_cooling_ctrl_t *ctrl) {
  /* Simulator doesn't model cooling in detail */
  return EA_HAL_ERR_NOT_SUPPORTED;
}

static int sim_emergency_stop(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  printf("[Simulator] 🚨 EMERGENCY STOP: Throttling to minimum\n");

  /* Throttle to minimum safe state */
  sim_ctx->current_freq_mhz = SIM_MIN_FREQ_MHZ;
  sim_ctx->current_top_k = SIM_MIN_K;

  calculate_physics(sim_ctx);

  return EA_HAL_OK;
}

static int sim_reset_to_defaults(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  printf("[Simulator] Resetting to defaults\n");

  sim_ctx->current_freq_mhz = SIM_MAX_FREQ_MHZ;
  sim_ctx->current_top_k = SIM_MAX_K;
  sim_ctx->current_power_limit_w = 0;

  calculate_physics(sim_ctx);

  return EA_HAL_OK;
}

/* ============================================================================
 * MoE Control Extension
 * ========================================================================= */

/**
 * Set MoE Top-K value
 *
 * This is an extension to the standard HAL for MoE-specific control.
 * In a real implementation, this would be part of the model runtime,
 * but for simulation we expose it directly.
 */
int sim_set_moe_top_k(void *ctx, int k) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;

  /* Clamp to valid range */
  if (k < SIM_MIN_K)
    k = SIM_MIN_K;
  if (k > SIM_MAX_K)
    k = SIM_MAX_K;

  printf("[Simulator] MoE Top-K change: %d → %d\n", sim_ctx->current_top_k, k);

  sim_ctx->current_top_k = k;

  /* Recalculate physics */
  calculate_physics(sim_ctx);

  return EA_HAL_OK;
}

/**
 * Get current MoE Top-K value
 */
int sim_get_moe_top_k(void *ctx) {
  if (!ctx)
    return -1;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;
  return sim_ctx->current_top_k;
}

/**
 * Get current throughput
 */
double sim_get_throughput(void *ctx) {
  if (!ctx)
    return 0.0;

  sim_context_t *sim_ctx = (sim_context_t *)ctx;
  return sim_ctx->current_throughput_tps;
}

/* ============================================================================
 * Driver Registration
 * ========================================================================= */

static const ea_device_driver_t simulator_driver = {
    .name = "Physics Simulator Driver",
    .version = "0.1.0",
    .device_type =
        EA_DEVICE_GPU_NVIDIA, /* Pretend to be NVIDIA for compatibility */
    .capabilities = EA_CAP_POWER_LIMIT | EA_CAP_FREQ_CONTROL |
                    EA_CAP_TEMP_MONITOR | EA_CAP_POWER_MONITOR |
                    EA_CAP_UTIL_MONITOR | EA_CAP_EMERGENCY_STOP,

    .init = sim_init,
    .shutdown = sim_shutdown,
    .get_telemetry = sim_get_telemetry,
    .get_device_info = sim_get_device_info,
    .set_power_limit = sim_set_power_limit,
    .set_frequency_range = sim_set_frequency_range,
    .set_cooling = sim_set_cooling,
    .emergency_stop = sim_emergency_stop,
    .reset_to_defaults = sim_reset_to_defaults};

const ea_device_driver_t *ea_hal_get_simulator_driver(void) {
  return &simulator_driver;
}
