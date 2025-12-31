/**
 * EA-AOL Power Source HAL Implementation (Linux)
 *
 * Reads power state from sysfs, faster and more accurate than OS APIs.
 *
 * License: BSD-2-Clause
 */

#include "ea_hal_power.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* sysfs paths */
#define SYSFS_AC_ONLINE "/sys/class/power_supply/AC/online"
#define SYSFS_BAT_CAPACITY "/sys/class/power_supply/BAT0/capacity"
#define SYSFS_BAT_ENERGY "/sys/class/power_supply/BAT0/energy_now"
#define SYSFS_BAT_POWER "/sys/class/power_supply/BAT0/power_now"
#define SYSFS_BAT_STATUS "/sys/class/power_supply/BAT0/status"

/* Thresholds */
#define CRITICAL_BATTERY_PCT 20
#define LOW_BATTERY_PCT 40

/**
 * Read integer from sysfs file
 */
static int read_sysfs_int(const char *path, int *value) {
  FILE *fp = fopen(path, "r");
  if (!fp) {
    return -1;
  }

  int ret = fscanf(fp, "%d", value);
  fclose(fp);

  return (ret == 1) ? 0 : -1;
}

/**
 * Read string from sysfs file
 */
static int read_sysfs_str(const char *path, char *buf, size_t size) {
  FILE *fp = fopen(path, "r");
  if (!fp) {
    return -1;
  }

  if (fgets(buf, size, fp) == NULL) {
    fclose(fp);
    return -1;
  }

  fclose(fp);

  /* Remove newline */
  size_t len = strlen(buf);
  if (len > 0 && buf[len - 1] == '\n') {
    buf[len - 1] = '\0';
  }

  return 0;
}

ea_power_state_t ea_hal_get_power_state(void) {
  int ac_online = 0;

  /* Check AC power */
  if (read_sysfs_int(SYSFS_AC_ONLINE, &ac_online) == 0 && ac_online) {
    return EA_POWER_GRID;
  }

  /* On battery - check capacity */
  int capacity = 100;
  if (read_sysfs_int(SYSFS_BAT_CAPACITY, &capacity) == 0) {
    if (capacity < CRITICAL_BATTERY_PCT) {
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

  /* Get power state */
  info->state = ea_hal_get_power_state();

  /* Get capacity */
  int capacity = 0;
  if (read_sysfs_int(SYSFS_BAT_CAPACITY, &capacity) == 0) {
    info->capacity_pct = (uint8_t)capacity;
  }

  /* Get remaining energy (µWh -> mWh) */
  int energy_now = 0;
  if (read_sysfs_int(SYSFS_BAT_ENERGY, &energy_now) == 0) {
    info->remaining_mwh = energy_now / 1000;
  }

  /* Get power consumption (µW -> mW) */
  int power_now = 0;
  if (read_sysfs_int(SYSFS_BAT_POWER, &power_now) == 0) {
    info->rate_mw = power_now / 1000;

    /* Calculate time to empty */
    if (power_now > 0 && energy_now > 0) {
      /* time = energy / power (hours -> seconds) */
      info->time_to_empty_s = (energy_now * 3600) / power_now;
    }
  }

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
