/**
 * EA-AOL Power Source HAL
 *
 * Detects power source (Grid/Battery/Critical) and enables
 * intelligent power management beyond OS capabilities.
 *
 * License: BSD-2-Clause
 */

#ifndef EA_HAL_POWER_H
#define EA_HAL_POWER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Power source states
 */
typedef enum {
  EA_POWER_GRID = 0, /**< AC power (unlimited) */
  EA_POWER_BATTERY,  /**< Battery power (limited) */
  EA_POWER_CRITICAL, /**< Battery critical (<20%) */
  EA_POWER_UNKNOWN   /**< Cannot determine */
} ea_power_state_t;

/**
 * Battery information
 */
typedef struct {
  ea_power_state_t state;
  uint8_t capacity_pct;     /**< 0-100% */
  uint32_t remaining_mwh;   /**< Remaining energy (mWh) */
  int32_t rate_mw;          /**< Discharge rate (mW, negative=discharging) */
  uint32_t time_to_empty_s; /**< Estimated time to empty (seconds) */
} ea_battery_info_t;

/**
 * Power management strategy
 */
typedef enum {
  EA_POWER_STRATEGY_PERFORMANCE = 0, /**< Grid: Max quality */
  EA_POWER_STRATEGY_BALANCED,        /**< Battery: Balance quality/duration */
  EA_POWER_STRATEGY_SURVIVAL         /**< Critical: Minimize power */
} ea_power_strategy_t;

/**
 * Get current power state
 *
 * @return Power state
 */
ea_power_state_t ea_hal_get_power_state(void);

/**
 * Get detailed battery information
 *
 * @param info Output battery info
 * @return 0 on success, negative on error
 */
int ea_hal_get_battery_info(ea_battery_info_t *info);

/**
 * Get recommended power strategy
 *
 * @return Recommended strategy based on current power state
 */
ea_power_strategy_t ea_hal_get_power_strategy(void);

/**
 * Calculate optimal Top-K for current power state
 *
 * @param base_k Base Top-K value (for Grid power)
 * @return Adjusted Top-K value
 */
uint32_t ea_hal_adjust_topk_for_power(uint32_t base_k);

#ifdef __cplusplus
}
#endif

#endif /* EA_HAL_POWER_H */
