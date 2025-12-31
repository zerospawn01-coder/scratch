/*
 * ea_metrics.h - EA-AOL Metrics & EPI Calculation
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 *
 * Implements EPI (Energy Per Inference) calculation and related metrics
 */

#ifndef EA_METRICS_H
#define EA_METRICS_H

#include <stdbool.h>
#include <stdint.h>


#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * EPI Calculation
 * ========================================================================= */

/**
 * EPI calculation method
 */
typedef enum {
  EPI_METHOD_ESTIMATED, /**< Model-based estimation */
  EPI_METHOD_MEASURED,  /**< Direct measurement */
  EPI_METHOD_HYBRID     /**< Combination of both */
} epi_method_t;

/**
 * EPI calculation parameters
 */
typedef struct {
  /* Model-based parameters */
  double flops_per_token;  /**< FLOPs per token */
  double mem_bw_per_token; /**< Memory bandwidth per token (bytes) */
  double alpha;            /**< Energy coefficient: J per FLOP */
  double beta;             /**< Energy coefficient: J per Byte */
  double overhead_j;       /**< Fixed overhead energy (J) */

  /* Measurement-based parameters */
  double power_w;        /**< Current power (Watts) */
  double throughput_tps; /**< Throughput (tokens/second) */

  /* Method selection */
  epi_method_t method;
} epi_params_t;

/**
 * EPI calculation result
 */
typedef struct {
  double epi_j_per_token;   /**< EPI in J/token */
  double confidence;        /**< Confidence [0.0, 1.0] */
  epi_method_t method_used; /**< Method used for calculation */
  uint64_t timestamp_ms;    /**< Calculation timestamp */
} epi_result_t;

/**
 * Calculate EPI using estimated method
 *
 * Formula: EPI = (FLOPs/token × α) + (Bytes/token × β) + overhead
 *
 * @param params EPI parameters
 * @param result Output EPI result
 * @return 0 on success, -1 on error
 */
int epi_calculate_estimated(const epi_params_t *params, epi_result_t *result);

/**
 * Calculate EPI using measured method
 *
 * Formula: EPI = Power (W) / Throughput (tokens/s)
 *
 * @param params EPI parameters
 * @param result Output EPI result
 * @return 0 on success, -1 on error
 */
int epi_calculate_measured(const epi_params_t *params, epi_result_t *result);

/**
 * Calculate EPI using hybrid method
 *
 * Combines estimated and measured with confidence weighting
 *
 * @param params EPI parameters
 * @param result Output EPI result
 * @return 0 on success, -1 on error
 */
int epi_calculate_hybrid(const epi_params_t *params, epi_result_t *result);

/**
 * Calculate EPI (auto-select method)
 *
 * @param params EPI parameters
 * @param result Output EPI result
 * @return 0 on success, -1 on error
 */
int epi_calculate(const epi_params_t *params, epi_result_t *result);

/* ============================================================================
 * Metrics Aggregation
 * ========================================================================= */

/**
 * Aggregated metrics over a time window
 */
typedef struct {
  /* Time window */
  uint64_t window_start_ms;
  uint64_t window_end_ms;
  uint64_t window_duration_ms;

  /* Power metrics */
  double power_avg_w;
  double power_min_w;
  double power_max_w;
  double power_stddev_w;

  /* EPI metrics */
  double epi_avg_j_per_token;
  double epi_min_j_per_token;
  double epi_max_j_per_token;
  double epi_stddev_j_per_token;

  /* Latency metrics */
  double latency_avg_ms;
  double latency_p50_ms;
  double latency_p95_ms;
  double latency_p99_ms;

  /* Throughput metrics */
  double throughput_avg_tps;
  double throughput_min_tps;
  double throughput_max_tps;

  /* Quality metrics */
  double quality_avg;
  double quality_min;

  /* Cumulative */
  uint64_t total_tokens;
  double total_energy_j;

  /* Sample count */
  int num_samples;
} metrics_aggregate_t;

/**
 * Metrics aggregator context
 */
typedef struct metrics_aggregator_t metrics_aggregator_t;

/**
 * Create metrics aggregator
 *
 * @param window_ms Aggregation window size (milliseconds)
 * @return Aggregator context, or NULL on error
 */
metrics_aggregator_t *metrics_aggregator_create(uint64_t window_ms);

/**
 * Add sample to aggregator
 *
 * @param agg Aggregator context
 * @param power_w Power (Watts)
 * @param epi_j_per_token EPI (J/token)
 * @param latency_ms Latency (milliseconds)
 * @param throughput_tps Throughput (tokens/second)
 * @param quality Quality score [0.0, 1.0]
 * @return 0 on success, -1 on error
 */
int metrics_aggregator_add_sample(metrics_aggregator_t *agg, double power_w,
                                  double epi_j_per_token, double latency_ms,
                                  double throughput_tps, double quality);

/**
 * Get aggregated metrics
 *
 * @param agg Aggregator context
 * @param aggregate Output aggregated metrics
 * @return 0 on success, -1 on error
 */
int metrics_aggregator_get(metrics_aggregator_t *agg,
                           metrics_aggregate_t *aggregate);

/**
 * Reset aggregator
 *
 * @param agg Aggregator context
 */
void metrics_aggregator_reset(metrics_aggregator_t *agg);

/**
 * Destroy aggregator
 *
 * @param agg Aggregator context
 */
void metrics_aggregator_destroy(metrics_aggregator_t *agg);

/* ============================================================================
 * Metrics Export
 * ========================================================================= */

/**
 * Export format
 */
typedef enum {
  EXPORT_FORMAT_JSON,
  EXPORT_FORMAT_CSV,
  EXPORT_FORMAT_PROMETHEUS
} export_format_t;

/**
 * Export metrics to string
 *
 * @param aggregate Aggregated metrics
 * @param format Export format
 * @param buffer Output buffer
 * @param buffer_size Buffer size
 * @return 0 on success, -1 on error
 */
int metrics_export(const metrics_aggregate_t *aggregate, export_format_t format,
                   char *buffer, size_t buffer_size);

/**
 * Export metrics to file
 *
 * @param aggregate Aggregated metrics
 * @param format Export format
 * @param filename Output filename
 * @return 0 on success, -1 on error
 */
int metrics_export_to_file(const metrics_aggregate_t *aggregate,
                           export_format_t format, const char *filename);

/* ============================================================================
 * Utility Functions
 * ========================================================================= */

/**
 * Get current timestamp in milliseconds
 */
uint64_t metrics_get_time_ms(void);

/**
 * Calculate standard deviation
 */
double metrics_stddev(const double *values, int count);

/**
 * Calculate percentile
 */
double metrics_percentile(const double *values, int count, double percentile);

#ifdef __cplusplus
}
#endif

#endif /* EA_METRICS_H */
