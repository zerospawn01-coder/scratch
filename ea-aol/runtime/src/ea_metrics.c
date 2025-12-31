/*
 * ea_metrics.c - EA-AOL Metrics Implementation
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 */

#include "ea_metrics.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>


/* ============================================================================
 * EPI Calculation
 * ========================================================================= */

int epi_calculate_estimated(const epi_params_t *params, epi_result_t *result) {
  if (!params || !result)
    return -1;

  /* Formula: EPI = (FLOPs/token × α) + (Bytes/token × β) + overhead */
  double compute_energy = params->flops_per_token * params->alpha;
  double memory_energy = params->mem_bw_per_token * params->beta;
  double total_energy = compute_energy + memory_energy + params->overhead_j;

  result->epi_j_per_token = total_energy;
  result->confidence = 0.7; /* Model-based has moderate confidence */
  result->method_used = EPI_METHOD_ESTIMATED;
  result->timestamp_ms = metrics_get_time_ms();

  return 0;
}

int epi_calculate_measured(const epi_params_t *params, epi_result_t *result) {
  if (!params || !result)
    return -1;

  /* Formula: EPI = Power (W) / Throughput (tokens/s) */
  if (params->throughput_tps <= 0) {
    return -1; /* Invalid throughput */
  }

  result->epi_j_per_token = params->power_w / params->throughput_tps;
  result->confidence = 0.9; /* Measurement-based has high confidence */
  result->method_used = EPI_METHOD_MEASURED;
  result->timestamp_ms = metrics_get_time_ms();

  return 0;
}

int epi_calculate_hybrid(const epi_params_t *params, epi_result_t *result) {
  if (!params || !result)
    return -1;

  epi_result_t estimated, measured;

  /* Calculate both */
  int est_ok = epi_calculate_estimated(params, &estimated);
  int meas_ok = epi_calculate_measured(params, &measured);

  if (est_ok != 0 && meas_ok != 0) {
    return -1; /* Both failed */
  }

  if (est_ok != 0) {
    /* Only measured available */
    *result = measured;
    return 0;
  }

  if (meas_ok != 0) {
    /* Only estimated available */
    *result = estimated;
    return 0;
  }

  /* Both available: weighted average based on confidence */
  double total_confidence = estimated.confidence + measured.confidence;
  double est_weight = estimated.confidence / total_confidence;
  double meas_weight = measured.confidence / total_confidence;

  result->epi_j_per_token = estimated.epi_j_per_token * est_weight +
                            measured.epi_j_per_token * meas_weight;

  result->confidence = (estimated.confidence + measured.confidence) / 2.0;
  result->method_used = EPI_METHOD_HYBRID;
  result->timestamp_ms = metrics_get_time_ms();

  return 0;
}

int epi_calculate(const epi_params_t *params, epi_result_t *result) {
  if (!params || !result)
    return -1;

  /* Auto-select method based on available data */
  switch (params->method) {
  case EPI_METHOD_ESTIMATED:
    return epi_calculate_estimated(params, result);

  case EPI_METHOD_MEASURED:
    return epi_calculate_measured(params, result);

  case EPI_METHOD_HYBRID:
    return epi_calculate_hybrid(params, result);

  default:
    /* Default to hybrid if both data sources available */
    if (params->throughput_tps > 0 && params->flops_per_token > 0) {
      return epi_calculate_hybrid(params, result);
    } else if (params->throughput_tps > 0) {
      return epi_calculate_measured(params, result);
    } else {
      return epi_calculate_estimated(params, result);
    }
  }
}

/* ============================================================================
 * Metrics Aggregation
 * ========================================================================= */

#define MAX_SAMPLES 1000

struct metrics_aggregator_t {
  uint64_t window_ms;
  uint64_t window_start_ms;

  /* Sample buffers */
  double power_samples[MAX_SAMPLES];
  double epi_samples[MAX_SAMPLES];
  double latency_samples[MAX_SAMPLES];
  double throughput_samples[MAX_SAMPLES];
  double quality_samples[MAX_SAMPLES];

  int num_samples;

  /* Cumulative */
  uint64_t total_tokens;
  double total_energy_j;
};

metrics_aggregator_t *metrics_aggregator_create(uint64_t window_ms) {
  metrics_aggregator_t *agg =
      (metrics_aggregator_t *)malloc(sizeof(metrics_aggregator_t));
  if (!agg)
    return NULL;

  memset(agg, 0, sizeof(metrics_aggregator_t));
  agg->window_ms = window_ms;
  agg->window_start_ms = metrics_get_time_ms();

  return agg;
}

int metrics_aggregator_add_sample(metrics_aggregator_t *agg, double power_w,
                                  double epi_j_per_token, double latency_ms,
                                  double throughput_tps, double quality) {
  if (!agg)
    return -1;

  uint64_t current_time = metrics_get_time_ms();

  /* Check if window expired */
  if (current_time - agg->window_start_ms > agg->window_ms) {
    /* Reset for new window */
    metrics_aggregator_reset(agg);
    agg->window_start_ms = current_time;
  }

  /* Check buffer space */
  if (agg->num_samples >= MAX_SAMPLES) {
    return -1; /* Buffer full */
  }

  /* Add sample */
  int idx = agg->num_samples;
  agg->power_samples[idx] = power_w;
  agg->epi_samples[idx] = epi_j_per_token;
  agg->latency_samples[idx] = latency_ms;
  agg->throughput_samples[idx] = throughput_tps;
  agg->quality_samples[idx] = quality;

  agg->num_samples++;

  /* Update cumulative */
  agg->total_energy_j += epi_j_per_token;
  agg->total_tokens += 1; /* Simplified: assume 1 token per sample */

  return 0;
}

static double calculate_avg(const double *values, int count) {
  if (count == 0)
    return 0.0;

  double sum = 0.0;
  for (int i = 0; i < count; i++) {
    sum += values[i];
  }
  return sum / count;
}

static double calculate_min(const double *values, int count) {
  if (count == 0)
    return 0.0;

  double min = values[0];
  for (int i = 1; i < count; i++) {
    if (values[i] < min)
      min = values[i];
  }
  return min;
}

static double calculate_max(const double *values, int count) {
  if (count == 0)
    return 0.0;

  double max = values[0];
  for (int i = 1; i < count; i++) {
    if (values[i] > max)
      max = values[i];
  }
  return max;
}

double metrics_stddev(const double *values, int count) {
  if (count < 2)
    return 0.0;

  double avg = calculate_avg(values, count);
  double sum_sq_diff = 0.0;

  for (int i = 0; i < count; i++) {
    double diff = values[i] - avg;
    sum_sq_diff += diff * diff;
  }

  return sqrt(sum_sq_diff / (count - 1));
}

static int compare_double(const void *a, const void *b) {
  double diff = *(const double *)a - *(const double *)b;
  return (diff > 0) - (diff < 0);
}

double metrics_percentile(const double *values, int count, double percentile) {
  if (count == 0)
    return 0.0;

  /* Copy and sort */
  double *sorted = (double *)malloc(count * sizeof(double));
  memcpy(sorted, values, count * sizeof(double));
  qsort(sorted, count, sizeof(double), compare_double);

  /* Calculate index */
  double index = (percentile / 100.0) * (count - 1);
  int lower = (int)floor(index);
  int upper = (int)ceil(index);

  double result;
  if (lower == upper) {
    result = sorted[lower];
  } else {
    double weight = index - lower;
    result = sorted[lower] * (1.0 - weight) + sorted[upper] * weight;
  }

  free(sorted);
  return result;
}

int metrics_aggregator_get(metrics_aggregator_t *agg,
                           metrics_aggregate_t *aggregate) {
  if (!agg || !aggregate)
    return -1;

  memset(aggregate, 0, sizeof(metrics_aggregate_t));

  /* Time window */
  aggregate->window_start_ms = agg->window_start_ms;
  aggregate->window_end_ms = metrics_get_time_ms();
  aggregate->window_duration_ms =
      aggregate->window_end_ms - aggregate->window_start_ms;

  /* Sample count */
  aggregate->num_samples = agg->num_samples;

  if (agg->num_samples == 0) {
    return 0; /* No samples */
  }

  /* Power metrics */
  aggregate->power_avg_w = calculate_avg(agg->power_samples, agg->num_samples);
  aggregate->power_min_w = calculate_min(agg->power_samples, agg->num_samples);
  aggregate->power_max_w = calculate_max(agg->power_samples, agg->num_samples);
  aggregate->power_stddev_w =
      metrics_stddev(agg->power_samples, agg->num_samples);

  /* EPI metrics */
  aggregate->epi_avg_j_per_token =
      calculate_avg(agg->epi_samples, agg->num_samples);
  aggregate->epi_min_j_per_token =
      calculate_min(agg->epi_samples, agg->num_samples);
  aggregate->epi_max_j_per_token =
      calculate_max(agg->epi_samples, agg->num_samples);
  aggregate->epi_stddev_j_per_token =
      metrics_stddev(agg->epi_samples, agg->num_samples);

  /* Latency metrics */
  aggregate->latency_avg_ms =
      calculate_avg(agg->latency_samples, agg->num_samples);
  aggregate->latency_p50_ms =
      metrics_percentile(agg->latency_samples, agg->num_samples, 50.0);
  aggregate->latency_p95_ms =
      metrics_percentile(agg->latency_samples, agg->num_samples, 95.0);
  aggregate->latency_p99_ms =
      metrics_percentile(agg->latency_samples, agg->num_samples, 99.0);

  /* Throughput metrics */
  aggregate->throughput_avg_tps =
      calculate_avg(agg->throughput_samples, agg->num_samples);
  aggregate->throughput_min_tps =
      calculate_min(agg->throughput_samples, agg->num_samples);
  aggregate->throughput_max_tps =
      calculate_max(agg->throughput_samples, agg->num_samples);

  /* Quality metrics */
  aggregate->quality_avg =
      calculate_avg(agg->quality_samples, agg->num_samples);
  aggregate->quality_min =
      calculate_min(agg->quality_samples, agg->num_samples);

  /* Cumulative */
  aggregate->total_tokens = agg->total_tokens;
  aggregate->total_energy_j = agg->total_energy_j;

  return 0;
}

void metrics_aggregator_reset(metrics_aggregator_t *agg) {
  if (!agg)
    return;

  agg->num_samples = 0;
  agg->total_tokens = 0;
  agg->total_energy_j = 0.0;
}

void metrics_aggregator_destroy(metrics_aggregator_t *agg) { free(agg); }

/* ============================================================================
 * Metrics Export
 * ========================================================================= */

int metrics_export(const metrics_aggregate_t *aggregate, export_format_t format,
                   char *buffer, size_t buffer_size) {
  if (!aggregate || !buffer)
    return -1;

  switch (format) {
  case EXPORT_FORMAT_JSON:
    snprintf(buffer, buffer_size,
             "{\n"
             "  \"window\": {\n"
             "    \"start_ms\": %llu,\n"
             "    \"end_ms\": %llu,\n"
             "    \"duration_ms\": %llu\n"
             "  },\n"
             "  \"power\": {\n"
             "    \"avg_w\": %.2f,\n"
             "    \"min_w\": %.2f,\n"
             "    \"max_w\": %.2f,\n"
             "    \"stddev_w\": %.2f\n"
             "  },\n"
             "  \"epi\": {\n"
             "    \"avg_j_per_token\": %.4f,\n"
             "    \"min_j_per_token\": %.4f,\n"
             "    \"max_j_per_token\": %.4f,\n"
             "    \"stddev_j_per_token\": %.4f\n"
             "  },\n"
             "  \"latency\": {\n"
             "    \"avg_ms\": %.2f,\n"
             "    \"p50_ms\": %.2f,\n"
             "    \"p95_ms\": %.2f,\n"
             "    \"p99_ms\": %.2f\n"
             "  },\n"
             "  \"throughput\": {\n"
             "    \"avg_tps\": %.2f,\n"
             "    \"min_tps\": %.2f,\n"
             "    \"max_tps\": %.2f\n"
             "  },\n"
             "  \"quality\": {\n"
             "    \"avg\": %.3f,\n"
             "    \"min\": %.3f\n"
             "  },\n"
             "  \"cumulative\": {\n"
             "    \"total_tokens\": %llu,\n"
             "    \"total_energy_j\": %.2f\n"
             "  },\n"
             "  \"num_samples\": %d\n"
             "}\n",
             (unsigned long long)aggregate->window_start_ms,
             (unsigned long long)aggregate->window_end_ms,
             (unsigned long long)aggregate->window_duration_ms,
             aggregate->power_avg_w, aggregate->power_min_w,
             aggregate->power_max_w, aggregate->power_stddev_w,
             aggregate->epi_avg_j_per_token, aggregate->epi_min_j_per_token,
             aggregate->epi_max_j_per_token, aggregate->epi_stddev_j_per_token,
             aggregate->latency_avg_ms, aggregate->latency_p50_ms,
             aggregate->latency_p95_ms, aggregate->latency_p99_ms,
             aggregate->throughput_avg_tps, aggregate->throughput_min_tps,
             aggregate->throughput_max_tps, aggregate->quality_avg,
             aggregate->quality_min,
             (unsigned long long)aggregate->total_tokens,
             aggregate->total_energy_j, aggregate->num_samples);
    break;

  case EXPORT_FORMAT_CSV:
    snprintf(
        buffer, buffer_size,
        "timestamp,power_avg,epi_avg,latency_p99,throughput_avg,quality_avg\n"
        "%llu,%.2f,%.4f,%.2f,%.2f,%.3f\n",
        (unsigned long long)aggregate->window_end_ms, aggregate->power_avg_w,
        aggregate->epi_avg_j_per_token, aggregate->latency_p99_ms,
        aggregate->throughput_avg_tps, aggregate->quality_avg);
    break;

  case EXPORT_FORMAT_PROMETHEUS:
    snprintf(buffer, buffer_size,
             "# HELP ea_aol_power_watts Current power consumption\n"
             "# TYPE ea_aol_power_watts gauge\n"
             "ea_aol_power_watts %.2f\n"
             "# HELP ea_aol_epi_joules_per_token Energy per inference\n"
             "# TYPE ea_aol_epi_joules_per_token gauge\n"
             "ea_aol_epi_joules_per_token %.4f\n"
             "# HELP ea_aol_latency_p99_ms P99 latency\n"
             "# TYPE ea_aol_latency_p99_ms gauge\n"
             "ea_aol_latency_p99_ms %.2f\n",
             aggregate->power_avg_w, aggregate->epi_avg_j_per_token,
             aggregate->latency_p99_ms);
    break;

  default:
    return -1;
  }

  return 0;
}

int metrics_export_to_file(const metrics_aggregate_t *aggregate,
                           export_format_t format, const char *filename) {
  char buffer[4096];

  int result = metrics_export(aggregate, format, buffer, sizeof(buffer));
  if (result != 0)
    return result;

  FILE *f = fopen(filename, "w");
  if (!f)
    return -1;

  fprintf(f, "%s", buffer);
  fclose(f);

  return 0;
}

/* ============================================================================
 * Utility Functions
 * ========================================================================= */

uint64_t metrics_get_time_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
