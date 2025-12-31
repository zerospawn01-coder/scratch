/*
 * ea_hal_nvidia.c - NVIDIA GPU Driver Implementation
 * 
 * License: BSD-2-Clause
 * Version: 0.1.0
 * 
 * This is the reference implementation for NVIDIA GPUs using NVML.
 * Other vendors (AMD, Intel) would create similar files.
 */

#include "ea_hal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ============================================================================
 * NVML Integration (Conditional Compilation)
 * ========================================================================= */

#ifdef EA_USE_NVML
#include <nvml.h>

typedef struct {
    nvmlDevice_t device;
    int device_index;
    bool initialized;
} nv_context_t;

#else
/* Mock implementation for systems without NVML */
typedef struct {
    int device_index;
    bool initialized;
    double mock_power;
    double mock_temp;
    uint32_t mock_freq;
} nv_context_t;
#endif

/* ============================================================================
 * Safety Limits (from Day 2 security spec)
 * ========================================================================= */

#define NV_FREQ_MIN_MHZ 200
#define NV_FREQ_MAX_MHZ 2000
#define NV_POWER_MIN_W  50
#define NV_POWER_MAX_W  400

/* ============================================================================
 * Helper Functions
 * ========================================================================= */

static int clamp_freq(int freq_mhz) {
    if (freq_mhz < NV_FREQ_MIN_MHZ) return NV_FREQ_MIN_MHZ;
    if (freq_mhz > NV_FREQ_MAX_MHZ) return NV_FREQ_MAX_MHZ;
    return freq_mhz;
}

static int clamp_power(int power_w) {
    if (power_w < NV_POWER_MIN_W) return NV_POWER_MIN_W;
    if (power_w > NV_POWER_MAX_W) return NV_POWER_MAX_W;
    return power_w;
}

/* ============================================================================
 * Driver Implementation
 * ========================================================================= */

static int nv_init(void** ctx, int device_index) {
    nv_context_t* nv_ctx = (nv_context_t*)malloc(sizeof(nv_context_t));
    if (!nv_ctx) {
        return EA_HAL_ERR_NOT_INITIALIZED;
    }
    
    nv_ctx->device_index = device_index;
    nv_ctx->initialized = false;
    
#ifdef EA_USE_NVML
    nvmlReturn_t result = nvmlInit();
    if (result != NVML_SUCCESS) {
        free(nv_ctx);
        return EA_HAL_ERR_NOT_INITIALIZED;
    }
    
    result = nvmlDeviceGetHandleByIndex(device_index, &nv_ctx->device);
    if (result != NVML_SUCCESS) {
        nvmlShutdown();
        free(nv_ctx);
        return EA_HAL_ERR_INVALID_PARAM;
    }
    
    nv_ctx->initialized = true;
#else
    /* Mock mode */
    nv_ctx->initialized = true;
    nv_ctx->mock_power = 150.0;
    nv_ctx->mock_temp = 65.0;
    nv_ctx->mock_freq = 1500;
    
    printf("[NVHAL] Mock mode: Initialized GPU %d\n", device_index);
#endif
    
    *ctx = nv_ctx;
    return EA_HAL_OK;
}

static int nv_shutdown(void* ctx) {
    if (!ctx) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    
#ifdef EA_USE_NVML
    if (nv_ctx->initialized) {
        nvmlShutdown();
    }
#else
    printf("[NVHAL] Mock mode: Shutdown GPU %d\n", nv_ctx->device_index);
#endif
    
    free(nv_ctx);
    return EA_HAL_OK;
}

static int nv_get_telemetry(void* ctx, ea_telemetry_t* telemetry) {
    if (!ctx || !telemetry) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    if (!nv_ctx->initialized) return EA_HAL_ERR_NOT_INITIALIZED;
    
#ifdef EA_USE_NVML
    nvmlReturn_t result;
    unsigned int power_mw;
    unsigned int temp;
    nvmlUtilization_t util;
    unsigned int freq;
    
    /* Get power */
    result = nvmlDeviceGetPowerUsage(nv_ctx->device, &power_mw);
    telemetry->power_w = (result == NVML_SUCCESS) ? (power_mw / 1000.0) : -1.0;
    
    /* Get temperature */
    result = nvmlDeviceGetTemperature(nv_ctx->device, NVML_TEMPERATURE_GPU, &temp);
    telemetry->temp_c = (result == NVML_SUCCESS) ? (double)temp : -1.0;
    
    /* Get utilization */
    result = nvmlDeviceGetUtilizationRates(nv_ctx->device, &util);
    telemetry->utilization = (result == NVML_SUCCESS) ? (util.gpu / 100.0) : -1.0;
    
    /* Get frequency */
    result = nvmlDeviceGetClockInfo(nv_ctx->device, NVML_CLOCK_GRAPHICS, &freq);
    telemetry->freq_mhz = (result == NVML_SUCCESS) ? (double)freq : -1.0;
    
#else
    /* Mock mode: Simulate realistic values */
    telemetry->power_w = nv_ctx->mock_power + ((rand() % 20) - 10);
    telemetry->temp_c = nv_ctx->mock_temp + ((rand() % 10) - 5);
    telemetry->utilization = 0.7 + ((rand() % 30) / 100.0);
    telemetry->freq_mhz = nv_ctx->mock_freq;
#endif
    
    /* Timestamp */
    telemetry->timestamp_ms = (uint64_t)time(NULL) * 1000;
    
    return EA_HAL_OK;
}

static int nv_get_device_info(void* ctx, char* buffer, size_t buffer_size) {
    if (!ctx || !buffer) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    
#ifdef EA_USE_NVML
    char name[NVML_DEVICE_NAME_BUFFER_SIZE];
    nvmlReturn_t result = nvmlDeviceGetName(nv_ctx->device, name, sizeof(name));
    
    if (result == NVML_SUCCESS) {
        snprintf(buffer, buffer_size, "NVIDIA %s (GPU %d)", name, nv_ctx->device_index);
    } else {
        snprintf(buffer, buffer_size, "NVIDIA GPU %d", nv_ctx->device_index);
    }
#else
    snprintf(buffer, buffer_size, "NVIDIA GPU %d (Mock)", nv_ctx->device_index);
#endif
    
    return EA_HAL_OK;
}

static int nv_set_power_limit(void* ctx, const ea_power_limit_t* limit) {
    if (!ctx || !limit) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    if (!nv_ctx->initialized) return EA_HAL_ERR_NOT_INITIALIZED;
    
    /* ✅ SECURITY: Clamp to safe range */
    int safe_limit = clamp_power((int)limit->limit_w);
    
#ifdef EA_USE_NVML
    /* Convert to milliwatts */
    unsigned int limit_mw = safe_limit * 1000;
    
    nvmlReturn_t result = nvmlDeviceSetPowerManagementLimit(nv_ctx->device, limit_mw);
    
    if (result == NVML_SUCCESS) {
        return EA_HAL_OK;
    } else if (result == NVML_ERROR_NO_PERMISSION) {
        return EA_HAL_ERR_PERMISSION;
    } else {
        return EA_HAL_ERR_HARDWARE;
    }
#else
    /* Mock mode */
    nv_ctx->mock_power = safe_limit;
    printf("[NVHAL] Mock: Set power limit to %d W\n", safe_limit);
    return EA_HAL_OK;
#endif
}

static int nv_set_frequency_range(void* ctx, const ea_freq_range_t* range) {
    if (!ctx || !range) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    if (!nv_ctx->initialized) return EA_HAL_ERR_NOT_INITIALIZED;
    
    /* ✅ SECURITY: Clamp to safe range */
    uint32_t safe_min = clamp_freq(range->min_mhz);
    uint32_t safe_max = clamp_freq(range->max_mhz);
    
#ifdef EA_USE_NVML
    nvmlReturn_t result = nvmlDeviceSetGpuLockedClocks(
        nv_ctx->device, 
        safe_min, 
        safe_max
    );
    
    if (result == NVML_SUCCESS) {
        return EA_HAL_OK;
    } else if (result == NVML_ERROR_NO_PERMISSION) {
        return EA_HAL_ERR_PERMISSION;
    } else {
        return EA_HAL_ERR_HARDWARE;
    }
#else
    /* Mock mode */
    nv_ctx->mock_freq = (safe_min + safe_max) / 2;
    printf("[NVHAL] Mock: Set frequency range [%u, %u] MHz\n", safe_min, safe_max);
    return EA_HAL_OK;
#endif
}

static int nv_set_cooling(void* ctx, const ea_cooling_ctrl_t* ctrl) {
    /* NVIDIA GPUs typically don't expose direct fan control via NVML */
    /* This would require nvidia-settings or similar tools */
    return EA_HAL_ERR_NOT_SUPPORTED;
}

static int nv_emergency_stop(void* ctx) {
    if (!ctx) return EA_HAL_ERR_INVALID_PARAM;
    
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    
    /* Set to minimum safe frequency */
    ea_freq_range_t safe_range = {
        .min_mhz = NV_FREQ_MIN_MHZ,
        .max_mhz = NV_FREQ_MIN_MHZ
    };
    
    int result = nv_set_frequency_range(ctx, &safe_range);
    
    printf("[NVHAL] EMERGENCY STOP: GPU %d throttled to %u MHz\n", 
           nv_ctx->device_index, NV_FREQ_MIN_MHZ);
    
    return result;
}

static int nv_reset_to_defaults(void* ctx) {
    if (!ctx) return EA_HAL_ERR_INVALID_PARAM;
    
#ifdef EA_USE_NVML
    nv_context_t* nv_ctx = (nv_context_t*)ctx;
    
    /* Reset locked clocks */
    nvmlDeviceResetGpuLockedClocks(nv_ctx->device);
    
    /* Reset power limit to default */
    unsigned int default_limit;
    nvmlDeviceGetPowerManagementDefaultLimit(nv_ctx->device, &default_limit);
    nvmlDeviceSetPowerManagementLimit(nv_ctx->device, default_limit);
    
    return EA_HAL_OK;
#else
    printf("[NVHAL] Mock: Reset to defaults\n");
    return EA_HAL_OK;
#endif
}

/* ============================================================================
 * Driver Registration
 * ========================================================================= */

static const ea_device_driver_t nvidia_driver = {
    .name = "NVIDIA NVML Driver",
    .version = "0.1.0",
    .device_type = EA_DEVICE_GPU_NVIDIA,
    .capabilities = EA_CAP_POWER_LIMIT | 
                    EA_CAP_FREQ_CONTROL | 
                    EA_CAP_TEMP_MONITOR | 
                    EA_CAP_POWER_MONITOR | 
                    EA_CAP_UTIL_MONITOR | 
                    EA_CAP_EMERGENCY_STOP,
    
    .init = nv_init,
    .shutdown = nv_shutdown,
    .get_telemetry = nv_get_telemetry,
    .get_device_info = nv_get_device_info,
    .set_power_limit = nv_set_power_limit,
    .set_frequency_range = nv_set_frequency_range,
    .set_cooling = nv_set_cooling,
    .emergency_stop = nv_emergency_stop,
    .reset_to_defaults = nv_reset_to_defaults
};

const ea_device_driver_t* ea_hal_get_nvidia_driver(void) {
    return &nvidia_driver;
}
