/*
 * ea_telemetry_server.h - Telemetry Server Interface
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 */

#ifndef EA_TELEMETRY_SERVER_H
#define EA_TELEMETRY_SERVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Telemetry Snapshot
 * ========================================================================= */

/**
 * Telemetry snapshot structure
 *
 * This is the data structure that gets streamed to monitoring clients.
 * It contains all relevant metrics for real-time visualization.
 */
typedef struct {
  /* Timestamp */
  uint64_t timestamp_ms;

  /* Hardware metrics */
  double power_w;
  double temp_c;
  double freq_mhz;
  double utilization;

  /* Performance metrics */
  double throughput_tps;
  double latency_ms;

  /* Energy metrics */
  double epi_j_per_token;

  /* Quality metrics */
  double quality;

  /* Control state */
  int active_k;               /**< Current MoE Top-K value */
  const char *violation;      /**< Current constraint violation (or NULL) */
  const char *current_action; /**< Current action being taken (or NULL) */
} telemetry_snapshot_t;

/* ============================================================================
 * Telemetry Server
 * ========================================================================= */

/**
 * Telemetry server context (opaque)
 */
typedef struct ea_telemetry_server_t ea_telemetry_server_t;

/**
 * Create telemetry server
 *
 * @param update_interval_ms Update interval in milliseconds
 * @return Server context, or NULL on error
 */
ea_telemetry_server_t *ea_telemetry_server_create(int update_interval_ms);

/**
 * Start telemetry server
 *
 * Starts a background thread that listens for client connections
 * and streams telemetry data.
 *
 * @param server Server context
 * @return 0 on success, -1 on error
 */
int ea_telemetry_server_start(ea_telemetry_server_t *server);

/**
 * Update telemetry snapshot
 *
 * Thread-safe update of current telemetry data.
 * This should be called from the main runtime loop.
 *
 * @param server Server context
 * @param snapshot New snapshot data
 */
void ea_telemetry_server_update_snapshot(ea_telemetry_server_t *server,
                                         const telemetry_snapshot_t *snapshot);

/**
 * Stop telemetry server
 *
 * Stops the background thread and closes all connections.
 *
 * @param server Server context
 */
void ea_telemetry_server_stop(ea_telemetry_server_t *server);

/**
 * Destroy telemetry server
 *
 * Frees all resources. Server must be stopped first.
 *
 * @param server Server context
 */
void ea_telemetry_server_destroy(ea_telemetry_server_t *server);

#ifdef __cplusplus
}
#endif

#endif /* EA_TELEMETRY_SERVER_H */
