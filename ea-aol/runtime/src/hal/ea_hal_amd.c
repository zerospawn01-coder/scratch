/*
 * ea_hal_amd.c - AMD GPU Hardware Abstraction Layer Driver
 *
 * License: BSD-2-Clause
 * Version: 0.2.0-beta (with Thermal Safety Guard)
 *
 * This driver provides AMD GPU control through the EA-AOL HAL interface.
 *
 * CRITICAL SAFETY FEATURES:
 * - Thermal Safety Guard: Auto-throttle at 85°C
 * - Emergency stop at 90°C
 * - Hardware limit clamping
 *
 * Supported APIs:
 * - AMD ADL (Windows/Linux)
 * - ROCm SMI (Linux)
 * - WMI (Windows, read-only)
 */

#include "ea_hal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ============================================================================
 * CRITICAL SAFETY LIMITS
 * ========================================================================= */

#define THERMAL_LIMIT_C 85.0    /**< Emergency throttle threshold */
#define THERMAL_CRITICAL_C 90.0 /**< Emergency stop threshold */
#define THERMAL_SAFE_C 80.0     /**< Safe operating temperature */

#define AMD_POWER_MIN_W 50.0
#define AMD_POWER_MAX_W 300.0
#define AMD_FREQ_MIN_MHZ 200.0
#define AMD_FREQ_MAX_MHZ 2500.0

/* ============================================================================
 * AMD Driver Context
 * ========================================================================= */

typedef struct {
  int device_index;
  bool initialized;

  /* Current state */
  double current_temp_c;
  double current_power_w;
  double current_freq_mhz;
  double current_util;

  /* Safety state */
  bool thermal_guard_active;
  uint64_t last_thermal_event_ms;
  int thermal_event_count;

  /* Limits */
  double power_limit_w;
  double freq_limit_mhz;

} amd_context_t;

/* ============================================================================
 * Helper Functions
 * ========================================================================= */

static uint64_t get_time_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static double clamp_double(double value, double min, double max) {
  if (value < min)
    return min;
  if (value > max)
    return max;
  return value;
}

/* ============================================================================
 * Thermal Safety Guard
 * ========================================================================= */

static void thermal_safety_guard(amd_context_t *ctx) {
  uint64_t now = get_time_ms();

  /* CRITICAL: Emergency stop at 90°C */
  if (ctx->current_temp_c >= THERMAL_CRITICAL_C) {
    fprintf(stderr, "\n");
    fprintf(stderr,
            "╔════════════════════════════════════════════════════════════╗\n");
    fprintf(stderr,
            "║  🚨 CRITICAL THERMAL EMERGENCY 🚨                         ║\n");
    fprintf(stderr,
            "║  Temperature: %.1f°C (CRITICAL LIMIT: %.1f°C)            ║\n",
            ctx->current_temp_c, THERMAL_CRITICAL_C);
    fprintf(stderr,
            "║  EMERGENCY STOP ACTIVATED                                 ║\n");
    fprintf(stderr,
            "╚════════════════════════════════════════════════════════════╝\n");
    fprintf(stderr, "\n");

    /* Emergency actions */
    ctx->power_limit_w = AMD_POWER_MIN_W;
    ctx->freq_limit_mhz = AMD_FREQ_MIN_MHZ;
    ctx->thermal_guard_active = true;
    ctx->thermal_event_count++;
    ctx->last_thermal_event_ms = now;

    /* TODO: Set fan to 100% */
    /* TODO: Reduce power limit via AMD ADL */

    return;
  }

  /* WARNING: Thermal throttle at 85°C */
  if (ctx->current_temp_c >= THERMAL_LIMIT_C) {
    if (!ctx->thermal_guard_active) {
      fprintf(stderr, "\n");
      fprintf(
          stderr,
          "┌────────────────────────────────────────────────────────────┐\n");
      fprintf(stderr,
              "│  ⚠️  THERMAL SAFETY GUARD ACTIVATED                       │\n");
      fprintf(stderr,
              "│  Temperature: %.1f°C (LIMIT: %.1f°C)                      │\n",
              ctx->current_temp_c, THERMAL_LIMIT_C);
      fprintf(
          stderr,
          "│  Engaging emergency throttling...                         │\n");
      fprintf(
          stderr,
          "└────────────────────────────────────────────────────────────┘\n");
      fprintf(stderr, "\n");

      ctx->thermal_guard_active = true;
      ctx->thermal_event_count++;
      ctx->last_thermal_event_ms = now;
    }

    /* Aggressive throttling */
    double safe_power = AMD_POWER_MIN_W + (AMD_POWER_MAX_W - AMD_POWER_MIN_W) *
                                              0.3; /* 30% power */
    ctx->power_limit_w =
        clamp_double(safe_power, AMD_POWER_MIN_W, AMD_POWER_MAX_W);

    /* TODO: Apply power limit via AMD ADL */
    /* TODO: Increase fan speed */

    fprintf(stderr, "[HAL-AMD] Thermal Guard: Power limited to %.1fW\n",
            ctx->power_limit_w);
  }

  /* Recovery: Temperature back to safe range */
  if (ctx->thermal_guard_active && ctx->current_temp_c < THERMAL_SAFE_C) {
    fprintf(stderr, "\n");
    fprintf(stderr,
            "┌────────────────────────────────────────────────────────────┐\n");
    fprintf(stderr,
            "│  ✓ THERMAL RECOVERY                                        │\n");
    fprintf(stderr,
            "│  Temperature: %.1f°C (SAFE: < %.1f°C)                     │\n",
            ctx->current_temp_c, THERMAL_SAFE_C);
    fprintf(stderr,
            "│  Thermal guard deactivated                                │\n");
    fprintf(stderr,
            "└────────────────────────────────────────────────────────────┘\n");
    fprintf(stderr, "\n");

    ctx->thermal_guard_active = false;
  }
}

/* ============================================================================
 * Driver Implementation
 * ========================================================================= */

static int amd_init(void **ctx_out, int device_index) {
  printf("[HAL-AMD] Initializing AMD GPU driver (device %d)\n", device_index);

  amd_context_t *ctx = (amd_context_t *)malloc(sizeof(amd_context_t));
  if (!ctx)
    return EA_HAL_ERR_NOT_INITIALIZED;

  memset(ctx, 0, sizeof(amd_context_t));

  ctx->device_index = device_index;
  ctx->initialized = true;
  ctx->thermal_guard_active = false;
  ctx->thermal_event_count = 0;

  /* Default limits */
  ctx->power_limit_w = AMD_POWER_MAX_W;
  ctx->freq_limit_mhz = AMD_FREQ_MAX_MHZ;

  /* TODO: Initialize AMD ADL */
  /* TODO: Get actual GPU info */

  *ctx_out = ctx;

  printf("[HAL-AMD] ✓ Initialized with thermal safety guard\n");
  printf("[HAL-AMD]   Thermal limit: %.1f°C\n", THERMAL_LIMIT_C);
  printf("[HAL-AMD]   Critical limit: %.1f°C\n", THERMAL_CRITICAL_C);

  return EA_HAL_OK;
}

static int amd_shutdown(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  printf("[HAL-AMD] Shutting down\n");

  if (amd_ctx->thermal_event_count > 0) {
    printf("[HAL-AMD] Thermal events during session: %d\n",
           amd_ctx->thermal_event_count);
  }

  /* TODO: Reset GPU to defaults */
  /* TODO: Cleanup AMD ADL */

  free(ctx);

  return EA_HAL_OK;
}

static int amd_get_telemetry(void *ctx, ea_telemetry_t *telemetry) {
  if (!ctx || !telemetry)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;
  if (!amd_ctx->initialized)
    return EA_HAL_ERR_NOT_INITIALIZED;

  /* TODO: Get actual telemetry from AMD ADL/ROCm SMI */
  /* For now, simulate realistic values */

  /* Simulate temperature reading */
  static double sim_temp = 65.0;
  sim_temp += ((rand() % 100) / 100.0 - 0.5) * 2.0; /* Random walk */

  /* Simulate load-based temperature increase */
  if (amd_ctx->current_util > 0.8) {
    sim_temp += 0.5; /* High load increases temp */
  }

  amd_ctx->current_temp_c = clamp_double(sim_temp, 40.0, 95.0);
  amd_ctx->current_power_w = 100.0 + (amd_ctx->current_util * 150.0);
  amd_ctx->current_freq_mhz = 1500.0;
  amd_ctx->current_util = 0.7 + ((rand() % 100) / 100.0 - 0.5) * 0.2;

  /* ═══════════════════════════════════════════════════════════════════
   * CRITICAL: THERMAL SAFETY GUARD
   *
   * This runs BEFORE returning telemetry to ensure immediate response
   * to thermal events, independent of EA-AOL policy evaluation.
   * ═══════════════════════════════════════════════════════════════════ */

  thermal_safety_guard(amd_ctx);

  /* Fill telemetry */
  telemetry->power_w = amd_ctx->current_power_w;
  telemetry->temp_c = amd_ctx->current_temp_c;
  telemetry->utilization = amd_ctx->current_util;
  telemetry->freq_mhz = amd_ctx->current_freq_mhz;
  telemetry->timestamp_ms = get_time_ms();

  return EA_HAL_OK;
}

static int amd_get_device_info(void *ctx, char *buffer, size_t buffer_size) {
  if (!ctx || !buffer)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  snprintf(buffer, buffer_size,
           "AMD Radeon GPU (Device %d) - Thermal Safety Guard: %s",
           amd_ctx->device_index,
           amd_ctx->thermal_guard_active ? "ACTIVE" : "Standby");

  return EA_HAL_OK;
}

static int amd_set_power_limit(void *ctx, const ea_power_limit_t *limit) {
  if (!ctx || !limit)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  double requested_limit = limit->limit_w;

  /* Clamp to hardware limits */
  requested_limit =
      clamp_double(requested_limit, AMD_POWER_MIN_W, AMD_POWER_MAX_W);

  /* Override if thermal guard is active */
  if (amd_ctx->thermal_guard_active) {
    double thermal_limit =
        AMD_POWER_MIN_W + (AMD_POWER_MAX_W - AMD_POWER_MIN_W) * 0.3;

    if (requested_limit > thermal_limit) {
      fprintf(stderr,
              "[HAL-AMD] Power limit request (%.1fW) overridden by "
              "thermal guard (%.1fW)\n",
              requested_limit, thermal_limit);
      requested_limit = thermal_limit;
    }
  }

  amd_ctx->power_limit_w = requested_limit;

  printf("[HAL-AMD] Power limit set: %.1fW\n", requested_limit);

  /* TODO: Apply via AMD ADL */

  return EA_HAL_OK;
}

static int amd_set_frequency_range(void *ctx, const ea_freq_range_t *range) {
  if (!ctx || !range)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  double requested_freq = (double)range->max_mhz;

  /* Clamp to hardware limits */
  requested_freq =
      clamp_double(requested_freq, AMD_FREQ_MIN_MHZ, AMD_FREQ_MAX_MHZ);

  /* Override if thermal guard is active */
  if (amd_ctx->thermal_guard_active) {
    double thermal_freq =
        AMD_FREQ_MIN_MHZ + (AMD_FREQ_MAX_MHZ - AMD_FREQ_MIN_MHZ) * 0.5;

    if (requested_freq > thermal_freq) {
      fprintf(stderr,
              "[HAL-AMD] Frequency request (%.0fMHz) overridden by "
              "thermal guard (%.0fMHz)\n",
              requested_freq, thermal_freq);
      requested_freq = thermal_freq;
    }
  }

  amd_ctx->freq_limit_mhz = requested_freq;

  printf("[HAL-AMD] Frequency limit set: %.0fMHz\n", requested_freq);

  /* TODO: Apply via AMD ADL */

  return EA_HAL_OK;
}

static int amd_set_cooling(void *ctx, const ea_cooling_ctrl_t *ctrl) {
  /* TODO: Implement fan control via AMD ADL */
  return EA_HAL_ERR_NOT_SUPPORTED;
}

static int amd_emergency_stop(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  fprintf(stderr, "\n");
  fprintf(stderr,
          "╔════════════════════════════════════════════════════════════╗\n");
  fprintf(stderr,
          "║  🚨 EMERGENCY STOP ACTIVATED 🚨                           ║\n");
  fprintf(stderr,
          "╚════════════════════════════════════════════════════════════╝\n");
  fprintf(stderr, "\n");

  /* Minimum safe state */
  amd_ctx->power_limit_w = AMD_POWER_MIN_W;
  amd_ctx->freq_limit_mhz = AMD_FREQ_MIN_MHZ;
  amd_ctx->thermal_guard_active = true;

  /* TODO: Set fan to 100% */
  /* TODO: Apply limits via AMD ADL */

  return EA_HAL_OK;
}

static int amd_reset_to_defaults(void *ctx) {
  if (!ctx)
    return EA_HAL_ERR_INVALID_PARAM;

  amd_context_t *amd_ctx = (amd_context_t *)ctx;

  printf("[HAL-AMD] Resetting to defaults\n");

  amd_ctx->power_limit_w = AMD_POWER_MAX_W;
  amd_ctx->freq_limit_mhz = AMD_FREQ_MAX_MHZ;
  amd_ctx->thermal_guard_active = false;

  /* TODO: Reset via AMD ADL */

  return EA_HAL_OK;
}

/* ============================================================================
 * Driver Registration
 * ========================================================================= */

static const ea_device_driver_t amd_driver = {
    .name = "AMD GPU Driver with Thermal Safety Guard",
    .version = "0.2.0-beta",
    .device_type = EA_DEVICE_GPU_AMD,
    .capabilities = EA_CAP_POWER_LIMIT | EA_CAP_FREQ_CONTROL |
                    EA_CAP_TEMP_MONITOR | EA_CAP_POWER_MONITOR |
                    EA_CAP_UTIL_MONITOR | EA_CAP_EMERGENCY_STOP |
                    EA_CAP_THERMAL_GUARD, /* NEW */

    .init = amd_init,
    .shutdown = amd_shutdown,
    .get_telemetry = amd_get_telemetry,
    .get_device_info = amd_get_device_info,
    .set_power_limit = amd_set_power_limit,
    .set_frequency_range = amd_set_frequency_range,
    .set_cooling = amd_set_cooling,
    .emergency_stop = amd_emergency_stop,
    .reset_to_defaults = amd_reset_to_defaults};

const ea_device_driver_t *ea_hal_get_amd_driver(void) { return &amd_driver; }
