/*
 * ea_runtime_core.c - EA-AOL Runtime Core with HAL Integration
 * 
 * License: BSD-2-Clause
 * Version: 0.1.0
 * 
 * This is the main runtime that ties everything together:
 * - IR loading and validation
 * - HAL device management
 * - Control loop execution
 * - Security enforcement
 */

#include "ea_ir.h"
#include "ea_hal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>

/* ============================================================================
 * Runtime Context
 * ========================================================================= */

typedef struct {
    ea_ir_t ir;
    const ea_device_driver_t* driver;
    void* device_ctx;
    bool initialized;
    uint64_t start_time_ms;
} ea_runtime_ctx_t;

/* ============================================================================
 * External Functions (from ea_ir_loader.c)
 * ========================================================================= */

extern int ea_ir_load_from_file(const char* filename, ea_ir_t* ir);
extern int validate_ir(const ea_ir_t* ir);
extern void ea_ir_print(const ea_ir_t* ir);
extern int clamp_freq(int freq_mhz);
extern int clamp_power(int power_w);
extern bool can_trigger_rule(const ea_rule_t* rule, uint64_t current_time_ms);

/* ============================================================================
 * External Functions (from ea_hal_nvidia.c)
 * ========================================================================= */

extern const ea_device_driver_t* ea_hal_get_nvidia_driver(void);

/* ============================================================================
 * Utility Functions
 * ========================================================================= */

static uint64_t get_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* ============================================================================
 * Runtime Initialization
 * ========================================================================= */

ea_runtime_ctx_t* ea_runtime_init(const char* ir_file, int device_index) {
    printf("[Runtime] Initializing EA-AOL Runtime v0.1.0\n");
    
    /* Allocate context */
    ea_runtime_ctx_t* ctx = (ea_runtime_ctx_t*)malloc(sizeof(ea_runtime_ctx_t));
    if (!ctx) {
        fprintf(stderr, "[Runtime] Error: Failed to allocate context\n");
        return NULL;
    }
    
    memset(ctx, 0, sizeof(ea_runtime_ctx_t));
    
    /* Load IR */
    printf("[Runtime] Loading IR from: %s\n", ir_file);
    if (ea_ir_load_from_file(ir_file, &ctx->ir) != 0) {
        fprintf(stderr, "[Runtime] Error: Failed to load IR\n");
        free(ctx);
        return NULL;
    }
    
    /* Print IR */
    ea_ir_print(&ctx->ir);
    
    /* Get device driver (NVIDIA for v0.1) */
    printf("[Runtime] Initializing device driver...\n");
    ctx->driver = ea_hal_get_nvidia_driver();
    if (!ctx->driver) {
        fprintf(stderr, "[Runtime] Error: Failed to get device driver\n");
        free(ctx);
        return NULL;
    }
    
    printf("[Runtime] Driver: %s v%s\n", ctx->driver->name, ctx->driver->version);
    
    /* Initialize device */
    int result = ctx->driver->init(&ctx->device_ctx, device_index);
    if (result != EA_HAL_OK) {
        fprintf(stderr, "[Runtime] Error: Failed to initialize device (code: %d)\n", result);
        free(ctx);
        return NULL;
    }
    
    /* Get device info */
    char device_info[256];
    ctx->driver->get_device_info(ctx->device_ctx, device_info, sizeof(device_info));
    printf("[Runtime] Device: %s\n", device_info);
    
    ctx->initialized = true;
    ctx->start_time_ms = get_time_ms();
    
    printf("[Runtime] Initialization complete\n\n");
    
    return ctx;
}

/* ============================================================================
 * Control Loop Tick
 * ========================================================================= */

int ea_runtime_tick(ea_runtime_ctx_t* ctx) {
    if (!ctx || !ctx->initialized) {
        return -1;
    }
    
    /* Get current telemetry */
    ea_telemetry_t telemetry;
    int result = ctx->driver->get_telemetry(ctx->device_ctx, &telemetry);
    if (result != EA_HAL_OK) {
        fprintf(stderr, "[Runtime] Warning: Failed to get telemetry\n");
        return result;
    }
    
    uint64_t current_time = get_time_ms();
    
    /* Print telemetry */
    printf("[Runtime] Telemetry: Power=%.1fW, Temp=%.1fC, Util=%.1f%%, Freq=%.0fMHz\n",
           telemetry.power_w, telemetry.temp_c, 
           telemetry.utilization * 100.0, telemetry.freq_mhz);
    
    /* Evaluate rules */
    for (int i = 0; i < ctx->ir.num_rules; i++) {
        ea_rule_t* rule = &ctx->ir.rules[i];
        
        /* ✅ SECURITY: Check cooldown */
        if (!can_trigger_rule(rule, current_time)) {
            continue;
        }
        
        /* Get metric value */
        double metric_value = 0.0;
        if (strcmp(rule->metric_name, "power_w") == 0) {
            metric_value = telemetry.power_w;
        } else if (strcmp(rule->metric_name, "temp_c") == 0) {
            metric_value = telemetry.temp_c;
        } else {
            continue;
        }
        
        /* Evaluate condition */
        bool triggered = false;
        if (strcmp(rule->op, ">") == 0) {
            triggered = (metric_value > rule->threshold);
        } else if (strcmp(rule->op, "<") == 0) {
            triggered = (metric_value < rule->threshold);
        }
        
        if (triggered) {
            printf("[Runtime] ⚠️  Rule triggered: %s %s %.1f (actual: %.1f)\n",
                   rule->metric_name, rule->op, rule->threshold, metric_value);
            
            /* Execute action */
            if (rule->action == ACTION_MOE_REDUCE_K) {
                printf("[Runtime] 🔧 Action: Reduce MoE Top-K (not implemented in v0.1)\n");
            } else if (rule->action == ACTION_DVFS_SCALE) {
                /* Reduce frequency */
                int current_freq = (int)telemetry.freq_mhz;
                int new_freq = current_freq - (int)rule->action_param;
                
                /* ✅ SECURITY: Clamp to safe range */
                new_freq = clamp_freq(new_freq);
                
                if (new_freq >= (int)rule->min_value) {
                    ea_freq_range_t range = {
                        .min_mhz = new_freq,
                        .max_mhz = new_freq
                    };
                    
                    result = ctx->driver->set_frequency_range(ctx->device_ctx, &range);
                    if (result == EA_HAL_OK) {
                        printf("[Runtime] ✓ Frequency reduced: %d → %d MHz\n", 
                               current_freq, new_freq);
                    } else {
                        fprintf(stderr, "[Runtime] Error: Failed to set frequency (code: %d)\n", 
                                result);
                    }
                }
            }
            
            /* Update last triggered time */
            rule->last_triggered_ms = current_time;
        }
    }
    
    return 0;
}

/* ============================================================================
 * Runtime Shutdown
 * ========================================================================= */

void ea_runtime_shutdown(ea_runtime_ctx_t* ctx) {
    if (!ctx) return;
    
    printf("\n[Runtime] Shutting down...\n");
    
    if (ctx->initialized && ctx->driver) {
        /* Reset device to defaults */
        if (ctx->driver->reset_to_defaults) {
            ctx->driver->reset_to_defaults(ctx->device_ctx);
        }
        
        /* Shutdown device */
        ctx->driver->shutdown(ctx->device_ctx);
    }
    
    free(ctx);
    
    printf("[Runtime] Shutdown complete\n");
}

/* ============================================================================
 * Main Entry Point (for testing)
 * ========================================================================= */

#ifdef EA_RUNTIME_STANDALONE

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <ir_file.json> [device_index]\n", argv[0]);
        return 1;
    }
    
    const char* ir_file = argv[1];
    int device_index = (argc > 2) ? atoi(argv[2]) : 0;
    
    printf("==========================================================\n");
    printf("EA-AOL Runtime v0.1.0\n");
    printf("==========================================================\n\n");
    
    /* Initialize runtime */
    ea_runtime_ctx_t* ctx = ea_runtime_init(ir_file, device_index);
    if (!ctx) {
        fprintf(stderr, "Failed to initialize runtime\n");
        return 1;
    }
    
    /* Run control loop */
    printf("==========================================================\n");
    printf("Running control loop (10 iterations)...\n");
    printf("==========================================================\n\n");
    
    for (int i = 0; i < 10; i++) {
        printf("--- Iteration %d ---\n", i + 1);
        
        int result = ea_runtime_tick(ctx);
        if (result != 0) {
            fprintf(stderr, "Control loop error: %d\n", result);
            break;
        }
        
        printf("\n");
        
        /* Sleep for telemetry interval */
        usleep(ctx->ir.telemetry_interval_ms * 1000);
    }
    
    /* Shutdown */
    ea_runtime_shutdown(ctx);
    
    printf("\n==========================================================\n");
    printf("Runtime test complete\n");
    printf("==========================================================\n");
    
    return 0;
}

#endif /* EA_RUNTIME_STANDALONE */
