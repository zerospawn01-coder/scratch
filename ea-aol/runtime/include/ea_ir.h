/*
 * ea_ir.h - EA-AOL Internal Representation v0.1
 * License: BSD-2-Clause
 * 
 * This header defines the core IR structure that bridges
 * the compiler (YAML → IR) and runtime (IR → Execution).
 */

#ifndef EA_IR_H
#define EA_IR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Security & Safety Constants
 * ========================================================================= */

/**
 * Hardware safety limits (NVIDIA A100 reference)
 * These prevent software bugs from damaging hardware
 */
#define GPU_FREQ_MIN_MHZ 200
#define GPU_FREQ_MAX_MHZ 2000
#define GPU_POWER_MIN_W  50
#define GPU_POWER_MAX_W  400

/**
 * Input validation limits
 * Prevent buffer overflow and resource exhaustion
 */
#define MAX_ID_LEN 63
#define MAX_METRIC_NAME_LEN 31
#define MAX_RULES 8

/* ============================================================================
 * 1. Constraints (The "Goals")
 * ========================================================================= */

/**
 * User-specified constraints that must be satisfied
 */
typedef struct {
    double power_cap_w;        /**< Maximum system power (Watts) */
    double latency_slo_ms;     /**< P99 latency target (milliseconds) */
    double quality_floor;      /**< Minimum quality ratio [0.0, 1.0] */
} ea_constraints_t;

/* ============================================================================
 * 2. Cost Model (The "Physics")
 * ========================================================================= */

/**
 * Energy cost model parameters
 * 
 * EPI_est = (flops_per_token * alpha) + (mem_bw_per_token * beta) + overhead
 */
typedef struct {
    double flops_per_token;    /**< FLOPs per token */
    double mem_bw_per_token;   /**< Memory bandwidth per token (Bytes) */
    double alpha;              /**< Energy coefficient: J per FLOP */
    double beta;               /**< Energy coefficient: J per Byte */
    double overhead_j;         /**< Fixed overhead energy (J) */
} ea_cost_model_t;

/* ============================================================================
 * 3. Control Plan (The "Action")
 * ========================================================================= */

/**
 * Action types that runtime can take
 */
typedef enum {
    ACTION_NONE = 0,           /**< No action */
    ACTION_DVFS_SCALE,         /**< Scale GPU frequency */
    ACTION_MOE_REDUCE_K,       /**< Reduce MoE Top-K */
    ACTION_LAYER_SKIP,         /**< Skip transformer layers */
    ACTION_BATCH_RESIZE,       /**< Adjust batch size */
    ACTION_QUANTIZE            /**< Apply quantization */
} ea_action_type_t;

/**
 * Control rule: if (metric op threshold) then action
 * 
 * Security features:
 * - cooldown_ms: Prevents oscillation
 * - min/max_value: Prevents extreme values
 */
typedef struct {
    char metric_name[MAX_METRIC_NAME_LEN + 1];  /**< Metric to monitor */
    char op[4];                /**< Comparison operator */
    double threshold;          /**< Threshold value */
    ea_action_type_t action;   /**< Action to take */
    double action_param;       /**< Action parameter */
    double min_value;          /**< Minimum allowed value */
    double max_value;          /**< Maximum allowed value */
    
    /* Security: Oscillation prevention */
    uint64_t cooldown_ms;      /**< Minimum time between actions (ms) */
    uint64_t last_triggered_ms;/**< Timestamp of last trigger */
} ea_rule_t;

/* ============================================================================
 * 4. Root IR Object
 * ========================================================================= */

/**
 * Complete IR structure
 * 
 * This is the compiled form of EA-AOL YAML that the runtime executes.
 * 
 * Security notes:
 * - All string fields have fixed sizes to prevent overflow
 * - num_rules is bounded by MAX_RULES
 * - Hardware limits enforced at runtime
 */
typedef struct {
    /* Metadata */
    char model_id[MAX_ID_LEN + 1];  /**< Model identifier */
    char ir_version[16];       /**< IR format version */
    uint64_t created_at;       /**< Compilation timestamp (Unix epoch) */
    
    /* Core components */
    ea_constraints_t constraints;
    ea_cost_model_t  cost_model;
    
    /* Control rules */
    int num_rules;             /**< Number of active rules */
    ea_rule_t rules[MAX_RULES];/**< Fixed-size array for safety */
    
    /* Runtime hints */
    int dvfs_granularity;      /**< 0=batch, 1=token, 2=layer */
    int telemetry_interval_ms; /**< Telemetry collection interval */
    int recompile_limit;       /**< Max automatic recompilations */
} ea_ir_t;

/* ============================================================================
 * 5. Security & Safety Functions
 * ========================================================================= */

/**
 * Safe string copy with length validation
 * 
 * @param dest Destination buffer
 * @param src Source string
 * @param max_len Maximum length (excluding null terminator)
 * @return 0 on success, -1 if source exceeds max_len
 */
int safe_copy_string(char* dest, const char* src, size_t max_len);

/**
 * Clamp GPU frequency to safe range
 * 
 * @param freq_mhz Requested frequency
 * @return Clamped frequency in range [GPU_FREQ_MIN_MHZ, GPU_FREQ_MAX_MHZ]
 */
int clamp_freq(int freq_mhz);

/**
 * Clamp GPU power to safe range
 * 
 * @param power_w Requested power
 * @return Clamped power in range [GPU_POWER_MIN_W, GPU_POWER_MAX_W]
 */
int clamp_power(int power_w);

/**
 * Validate IR structure
 * 
 * Checks:
 * - String lengths
 * - Numeric ranges
 * - Rule count
 * 
 * @param ir IR structure to validate
 * @return 0 if valid, error code otherwise
 */
int validate_ir(const ea_ir_t* ir);

/**
 * Check if rule can be triggered (cooldown check)
 * 
 * @param rule Rule to check
 * @param current_time_ms Current timestamp
 * @return true if cooldown period has elapsed
 */
bool can_trigger_rule(const ea_rule_t* rule, uint64_t current_time_ms);

/* ============================================================================
 * 6. Serialization Helpers
 * ========================================================================= */

/**
 * Serialize IR to JSON string
 * 
 * @param ir IR structure to serialize
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return 0 on success, -1 on error
 */
int ea_ir_to_json(const ea_ir_t* ir, char* buffer, size_t buffer_size);

/**
 * Deserialize IR from JSON string
 * 
 * @param json_str JSON string
 * @param ir Output IR structure
 * @return 0 on success, -1 on error
 */
int ea_ir_from_json(const char* json_str, ea_ir_t* ir);

/* ============================================================================
 * 7. Utility Functions
 * ========================================================================= */

/**
 * Get action type name as string
 */
const char* ea_action_type_name(ea_action_type_t action);

/**
 * Print IR to stdout (for debugging)
 */
void ea_ir_print(const ea_ir_t* ir);

#ifdef __cplusplus
}
#endif

#endif /* EA_IR_H */
