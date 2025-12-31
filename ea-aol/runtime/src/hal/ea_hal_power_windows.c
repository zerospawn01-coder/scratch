/**
 * EA-AOL Power Source HAL Implementation (Windows)
 *
 * Uses Windows Power Management API for battery state detection.
 *
 * License: BSD-2-Clause
 */

#include "ea_hal_power.h"

#ifdef _WIN32

#include <powrprof.h>
#include <string.h>
#include <windows.h>


#pragma comment(lib, "PowrProf.lib")

/* Thresholds */
#define CRITICAL_BATTERY_PCT 20
#define LOW_BATTERY_PCT 40

ea_power_state_t ea_hal_get_power_state(void) {
  SYSTEM_POWER_STATUS sps;

  if (!GetSystemPowerStatus(&sps)) {
    return EA_POWER_UNKNOWN;
  }

  /* Check AC power */
  if (sps.ACLineStatus == 1) {
    return EA_POWER_GRID;
  }

  /* On battery - check level */
  if (sps.BatteryLifePercent != 255) {
    if (sps.BatteryLifePercent < CRITICAL_BATTERY_PCT) {
      return EA_POWER_CRITICAL;
    }
  }

  return EA_POWER_BATTERY;
}

int ea_hal_get_battery_info(ea_battery_info_t *info) {
  if (!info) {
    return -1;
  }

  memset(info, 0, sizeof(ea_battery_info_t));

  SYSTEM_POWER_STATUS sps;
  if (!GetSystemPowerStatus(&sps)) {
    return -1;
  }

  /* Get power state */
  info->state = ea_hal_get_power_state();

  /* Get capacity */
  if (sps.BatteryLifePercent != 255) {
    info->capacity_pct = sps.BatteryLifePercent;
  }

  /* Get time to empty */
  if (sps.BatteryLifeTime != (DWORD)-1) {
    info->time_to_empty_s = sps.BatteryLifeTime;
  }

  /* Note: Windows doesn't provide remaining_mwh or rate_mw easily
   * Would need to use WMI or battery driver IOCTLs for that */

  return 0;
}

ea_power_strategy_t ea_hal_get_power_strategy(void) {
  ea_power_state_t state = ea_hal_get_power_state();

  switch (state) {
  case EA_POWER_GRID:
    return EA_POWER_STRATEGY_PERFORMANCE;

  case EA_POWER_BATTERY:
    return EA_POWER_STRATEGY_BALANCED;

  case EA_POWER_CRITICAL:
    return EA_POWER_STRATEGY_SURVIVAL;

  default:
    return EA_POWER_STRATEGY_BALANCED;
  }
}

uint32_t ea_hal_adjust_topk_for_power(uint32_t base_k) {
  ea_power_state_t state = ea_hal_get_power_state();

  switch (state) {
  case EA_POWER_GRID:
    /* Full performance */
    return base_k;

  case EA_POWER_BATTERY:
    /* Reduce to 50% */
    return (base_k + 1) / 2;

  case EA_POWER_CRITICAL:
    /* Survival mode: minimum (1) */
    return 1;

  default:
    return base_k;
  }
}

#endif /* _WIN32 */
