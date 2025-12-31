/**
 * EA-AOL Runtime C API
 * Version: 0.1.0
 * License: BSD-2-Clause
 * 
 * Energy-Aware AI Orchestration Language - Runtime Interface
 */

#ifndef EA_AOL_H
#define EA_AOL_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Version Information
 * ========================================================================= */

#define EA_AOL_VERSION_MAJOR 0
#define EA_AOL_VERSION_MINOR 1
#define EA_AOL_VERSION_PATCH 0

/**
 * Get runtime version string
 * @return Version string (e.g., "0.1.0")
 */
const char* ea_aol_version(void);

/* ============================================================================
 * Error Codes
 * ========================================================================= */

typedef enum {
    EA_AOL_OK = 0,
    EA_AOL_ERR_INVALID_PARAM = -1,
    EA_AOL_ERR_INVALID_YAML = -2,
    EA_AOL_ERR_COMPILATION_FAILED = -3,
    EA_AOL_ERR_SCHEDULE_FAILED = -4,
    EA_AOL_ERR_NOT_FOUND = -5,
    EA_AOL_ERR_TIMEOUT = -6,
    EA_AOL_ERR_POWER_CAP_EXCEEDED = -7,
    EA_AOL_ERR_QUALITY_FLOOR_VIOLATED = -8,
    EA_AOL_ERR_HARDWARE_UNAVAILABLE = -9,
    EA_AOL_ERR_OUT_OF_MEMORY = -10,
    EA_AOL_ERR_INTERNAL = -99
} ea_aol_error_t;

/**
 * Get human-readable error message
 * @param error Error code
 * @return Error message string
 */
const char* ea_aol_error_string(ea_aol_error_t error);

/* ============================================================================
 * Core Types
 * ========================================================================= */

/**
 * Opaque runtime context handle
 */
typedef struct ea_aol_ctx_t ea_aol_ctx_t;

/**
 * Inference request structure
 */
typedef struct {
    const char *request_id;      /**< Unique request identifier */
    const char *yaml_payload;    /**< EA-AOL YAML declaration (null-terminated) */
    uint64_t timeout_ms;         /**< Request timeout in milliseconds */
    void *user_data;             /**< Optional user data pointer */
} inference_request_t;

/**
 * Request state enumeration
 */
typedef enum {
    EA_AOL_STATE_PENDING = 0,    /**< Request queued, not started */
    EA_AOL_STATE_COMPILING = 1,  /**< IR compilation in progress */
    EA_AOL_STATE_RUNNING = 2,    /**< Inference executing */
    EA_AOL_STATE_SUCCEEDED = 3,  /**< Completed successfully */
    EA_AOL_STATE_FAILED = 4,     /**< Failed (see error field) */
    EA_AOL_STATE_CANCELLED = 5,  /**< Cancelled by user */
    EA_AOL_STATE_TIMEOUT = 6     /**< Timed out */
} ea_aol_state_t;

/**
 * Request status structure
 */
typedef struct {
    ea_aol_state_t state;        /**< Current state */
    double epi_j_per_token;      /**< Energy per token (J/token) */
    double power_w;              /**< Current power consumption (W) */
    double latency_ms;           /**< Latency (ms) */
    double quality_score;        /**< Quality metric [0.0, 1.0] */
    uint64_t tokens_generated;   /**< Number of tokens generated */
    const char *last_event;      /**< Last event message */
    ea_aol_error_t error_code;   /**< Error code if failed */
} request_status_t;

/**
 * Telemetry data point
 */
typedef struct {
    uint64_t timestamp_us;       /**< Timestamp (microseconds since epoch) */
    double epi_j_per_token;      /**< Energy per token */
    double power_w;              /**< Instantaneous power (W) */
    double temp_gpu_die_c;       /**< GPU die temperature (°C) */
    double temp_inlet_c;         /**< Inlet temperature (°C) */
    double gpu_freq_mhz;         /**< GPU frequency (MHz) */
    double gpu_util_pct;         /**< GPU utilization (%) */
} telemetry_point_t;

/**
 * Configuration structure
 */
typedef struct {
    const char *config_path;     /**< Path to config file (optional) */
    const char *log_level;       /**< Log level: DEBUG, INFO, WARN, ERROR */
    const char *telemetry_endpoint; /**< Telemetry endpoint URI */
    uint32_t max_concurrent_requests; /**< Max concurrent requests */
    uint32_t recompile_limit;    /**< Max automatic recompiles per request */
} ea_aol_config_t;

/* ============================================================================
 * Lifecycle Functions
 * ========================================================================= */

/**
 * Initialize EA-AOL runtime
 * 
 * @param config Configuration structure (NULL for defaults)
 * @return Runtime context handle, or NULL on failure
 */
ea_aol_ctx_t* ea_aol_init(const ea_aol_config_t *config);

/**
 * Shutdown EA-AOL runtime and free resources
 * 
 * @param ctx Runtime context
 */
void ea_aol_shutdown(ea_aol_ctx_t *ctx);

/* ============================================================================
 * Inference Operations
 * ========================================================================= */

/**
 * Submit inference request
 * 
 * @param ctx Runtime context
 * @param req Inference request structure
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_schedule(ea_aol_ctx_t *ctx, const inference_request_t *req);

/**
 * Get request status
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param status Output status structure
 * @return EA_AOL_OK on success, EA_AOL_ERR_NOT_FOUND if request doesn't exist
 */
int ea_aol_get_status(ea_aol_ctx_t *ctx, const char *request_id, 
                      request_status_t *status);

/**
 * Get request status as JSON string
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param out_json Output buffer for JSON string
 * @param out_size Size of output buffer
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_status_json(ea_aol_ctx_t *ctx, const char *request_id,
                       char *out_json, size_t out_size);

/**
 * Cancel running or pending request
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_cancel(ea_aol_ctx_t *ctx, const char *request_id);

/**
 * Wait for request completion
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param timeout_ms Timeout in milliseconds (0 = infinite)
 * @return EA_AOL_OK on success, EA_AOL_ERR_TIMEOUT on timeout
 */
int ea_aol_wait(ea_aol_ctx_t *ctx, const char *request_id, uint64_t timeout_ms);

/* ============================================================================
 * Metrics and Telemetry
 * ========================================================================= */

/**
 * Get EPI (Energy Per Inference) metric
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param out_epi_j_per_token Output EPI value (J/token)
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_get_epi(ea_aol_ctx_t *ctx, const char *request_id,
                   double *out_epi_j_per_token);

/**
 * Get latest telemetry point
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param telemetry Output telemetry structure
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_get_telemetry(ea_aol_ctx_t *ctx, const char *request_id,
                         telemetry_point_t *telemetry);

/**
 * Register telemetry callback
 * 
 * @param ctx Runtime context
 * @param callback Callback function
 * @param user_data User data pointer passed to callback
 * @return EA_AOL_OK on success, error code otherwise
 */
typedef void (*telemetry_callback_t)(const telemetry_point_t *point, void *user_data);

int ea_aol_register_telemetry_callback(ea_aol_ctx_t *ctx,
                                       telemetry_callback_t callback,
                                       void *user_data);

/* ============================================================================
 * Advanced Control
 * ========================================================================= */

/**
 * Force IR recompilation for a request
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_recompile(ea_aol_ctx_t *ctx, const char *request_id);

/**
 * Set runtime mode
 * 
 * @param ctx Runtime context
 * @param mode Mode string: "safe", "balanced", "aggressive"
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_set_mode(ea_aol_ctx_t *ctx, const char *mode);

/**
 * Get runtime statistics
 * 
 * @param ctx Runtime context
 * @param out_json Output buffer for JSON statistics
 * @param out_size Size of output buffer
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_get_stats(ea_aol_ctx_t *ctx, char *out_json, size_t out_size);

/* ============================================================================
 * Debugging and Introspection
 * ========================================================================= */

/**
 * Get compiled IR as JSON
 * 
 * @param ctx Runtime context
 * @param request_id Request identifier
 * @param out_json Output buffer for IR JSON
 * @param out_size Size of output buffer
 * @return EA_AOL_OK on success, error code otherwise
 */
int ea_aol_get_ir(ea_aol_ctx_t *ctx, const char *request_id,
                  char *out_json, size_t out_size);

/**
 * Enable/disable debug logging
 * 
 * @param ctx Runtime context
 * @param enable 1 to enable, 0 to disable
 */
void ea_aol_set_debug(ea_aol_ctx_t *ctx, int enable);

#ifdef __cplusplus
}
#endif

#endif /* EA_AOL_H */
