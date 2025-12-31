/*
 * ea_hal.h - EA-AOL Hardware Abstraction Layer
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 *
 * This is the "universal adapter" that allows EA-AOL to control
 * any hardware (NVIDIA, AMD, Intel, custom ASICs) through a
 * unified interface.
 *
 * Philosophy:
 * - We don't standardize hardware
 * - We standardize how EA-AOL talks to hardware
 * - This is the "energy control version of POSIX"
 */

#ifndef EA_HAL_H
#define EA_HAL_H

#include <stdbool.h>
#include <stdint.h>


#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Device Types
 * ========================================================================= */

/**
 * Device type enumeration
 * Allows runtime to identify what kind of device it's talking to
 */
typedef enum {
  EA_DEVICE_GPU_NVIDIA = 0,
  EA_DEVICE_GPU_AMD,
  EA_DEVICE_GPU_INTEL,
  EA_DEVICE_CPU,
  EA_DEVICE_PSU,
  EA_DEVICE_COOLING,
  EA_DEVICE_CUSTOM
} ea_device_type_t;

/**
 * Device capabilities flags
 * Not all devices support all operations
 */
typedef enum {
  EA_CAP_POWER_LIMIT = (1 << 0),    /**< Can set power limit */
  EA_CAP_FREQ_CONTROL = (1 << 1),   /**< Can control frequency */
  EA_CAP_TEMP_MONITOR = (1 << 2),   /**< Can read temperature */
  EA_CAP_POWER_MONITOR = (1 << 3),  /**< Can read power */
  EA_CAP_UTIL_MONITOR = (1 << 4),   /**< Can read utilization */
  EA_CAP_EMERGENCY_STOP = (1 << 5), /**< Supports emergency stop */
  EA_CAP_THERMAL_GUARD = (1 << 6)   /**< Has autonomous thermal safety guard */
} ea_device_caps_t;

/* ============================================================================
 * Telemetry Structures
 * ========================================================================= */

/**
 * Device telemetry snapshot
 * All fields are optional (set to -1.0 if not available)
 */
typedef struct {
  double power_w;        /**< Current power consumption (Watts) */
  double temp_c;         /**< Current temperature (Celsius) */
  double utilization;    /**< Utilization [0.0, 1.0] */
  double freq_mhz;       /**< Current frequency (MHz) */
  uint64_t timestamp_ms; /**< Measurement timestamp */
} ea_telemetry_t;

/* ============================================================================
 * Control Structures
 * ========================================================================= */

/**
 * Power limit request
 */
typedef struct {
  double limit_w;  /**< Power limit in Watts */
  bool persistent; /**< Persist across reboots */
} ea_power_limit_t;

/**
 * Frequency range request
 */
typedef struct {
  uint32_t min_mhz; /**< Minimum frequency (MHz) */
  uint32_t max_mhz; /**< Maximum frequency (MHz) */
} ea_freq_range_t;

/**
 * Cooling control request
 */
typedef struct {
  double fan_speed; /**< Fan speed [0.0, 1.0] */
  bool auto_mode;   /**< Enable automatic control */
} ea_cooling_ctrl_t;

/* ============================================================================
 * Error Codes
 * ========================================================================= */

typedef enum {
  EA_HAL_OK = 0,
  EA_HAL_ERR_NOT_SUPPORTED = -1,
  EA_HAL_ERR_PERMISSION = -2,
  EA_HAL_ERR_INVALID_PARAM = -3,
  EA_HAL_ERR_DEVICE_BUSY = -4,
  EA_HAL_ERR_TIMEOUT = -5,
  EA_HAL_ERR_HARDWARE = -6,
  EA_HAL_ERR_NOT_INITIALIZED = -7
} ea_hal_error_t;

/* ============================================================================
 * Device Driver Interface
 *
 * This is the core abstraction: a set of function pointers that
 * any hardware vendor can implement.
 * ========================================================================= */

/**
 * Hardware device driver interface
 *
 * Each hardware vendor implements these functions for their device.
 * EA-AOL runtime calls these functions without knowing the underlying
 * hardware details.
 *
 * Example:
 *   NVIDIA implements: ea_hal_nvidia.c
 *   AMD implements:    ea_hal_amd.c
 *   Intel implements:  ea_hal_intel.c
 */
typedef struct {
  /* ========================================================================
   * Metadata
   * ===================================================================== */

  const char *name;             /**< Driver name (e.g., "NVIDIA NVML") */
  const char *version;          /**< Driver version */
  ea_device_type_t device_type; /**< Device type */
  uint32_t capabilities;        /**< Capability flags (ea_device_caps_t) */

  /* ========================================================================
   * Lifecycle
   * ===================================================================== */

  /**
   * Initialize device
   *
   * @param ctx Device-specific context (allocated by driver)
   * @param device_index Device index (e.g., GPU 0, GPU 1)
   * @return EA_HAL_OK on success, error code otherwise
   */
  int (*init)(void **ctx, int device_index);

  /**
   * Shutdown device
   *
   * @param ctx Device context
   * @return EA_HAL_OK on success
   */
  int (*shutdown)(void *ctx);

  /* ========================================================================
   * Telemetry (Read Operations)
   * ===================================================================== */

  /**
   * Get current telemetry snapshot
   *
   * @param ctx Device context
   * @param telemetry Output telemetry structure
   * @return EA_HAL_OK on success, error code otherwise
   */
  int (*get_telemetry)(void *ctx, ea_telemetry_t *telemetry);

  /**
   * Get device information string
   *
   * @param ctx Device context
   * @param buffer Output buffer
   * @param buffer_size Buffer size
   * @return EA_HAL_OK on success
   */
  int (*get_device_info)(void *ctx, char *buffer, size_t buffer_size);

  /* ========================================================================
   * Control (Write Operations)
   * ===================================================================== */

  /**
   * Set power limit
   *
   * @param ctx Device context
   * @param limit Power limit configuration
   * @return EA_HAL_OK on success, EA_HAL_ERR_NOT_SUPPORTED if not available
   */
  int (*set_power_limit)(void *ctx, const ea_power_limit_t *limit);

  /**
   * Set frequency range
   *
   * @param ctx Device context
   * @param range Frequency range configuration
   * @return EA_HAL_OK on success, EA_HAL_ERR_NOT_SUPPORTED if not available
   */
  int (*set_frequency_range)(void *ctx, const ea_freq_range_t *range);

  /**
   * Set cooling control
   *
   * @param ctx Device context
   * @param ctrl Cooling configuration
   * @return EA_HAL_OK on success, EA_HAL_ERR_NOT_SUPPORTED if not available
   */
  int (*set_cooling)(void *ctx, const ea_cooling_ctrl_t *ctrl);

  /* ========================================================================
   * Safety
   * ===================================================================== */

  /**
   * Emergency stop
   *
   * Immediately throttle device to safe state.
   * This should NEVER fail.
   *
   * @param ctx Device context
   * @return EA_HAL_OK on success
   */
  int (*emergency_stop)(void *ctx);

  /**
   * Reset to safe defaults
   *
   * @param ctx Device context
   * @return EA_HAL_OK on success
   */
  int (*reset_to_defaults)(void *ctx);

} ea_device_driver_t;

/* ============================================================================
 * Driver Registry
 * ========================================================================= */

/**
 * Register a device driver
 *
 * Drivers call this during initialization to register themselves
 *
 * @param driver Driver interface
 * @return 0 on success, -1 on error
 */
int ea_hal_register_driver(const ea_device_driver_t *driver);

/**
 * Get driver by device type
 *
 * @param device_type Device type
 * @return Driver interface, or NULL if not found
 */
const ea_device_driver_t *ea_hal_get_driver(ea_device_type_t device_type);

/**
 * List all registered drivers
 *
 * @param drivers Output array
 * @param max_drivers Maximum number of drivers
 * @return Number of drivers found
 */
int ea_hal_list_drivers(const ea_device_driver_t **drivers, int max_drivers);

/* ============================================================================
 * Utility Functions
 * ========================================================================= */

/**
 * Get error string
 *
 * @param error Error code
 * @return Human-readable error message
 */
const char *ea_hal_error_string(ea_hal_error_t error);

/**
 * Check if device supports capability
 *
 * @param driver Driver interface
 * @param capability Capability to check
 * @return true if supported
 */
bool ea_hal_has_capability(const ea_device_driver_t *driver,
                           ea_device_caps_t capability);

#ifdef __cplusplus
}
#endif

#endif /* EA_HAL_H */
