/*
 * ea_ir_loader.c - EA-AOL IR Loader with Security
 * 
 * License: BSD-2-Clause
 * Version: 0.1.0
 * 
 * Loads IR JSON and populates ea_ir_t structure with strict validation
 */

#include "ea_ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/* ============================================================================
 * JSON Parsing (Simple implementation for v0.1)
 * For production, use a library like cJSON or json-c
 * ========================================================================= */

/* Simple JSON value extraction */
static bool json_get_string(const char* json, const char* key, char* out, size_t max_len) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":", key);
    
    const char* pos = strstr(json, search);
    if (!pos) return false;
    
    pos = strchr(pos, '"');
    if (!pos) return false;
    pos++; // Skip opening quote
    
    const char* end = strchr(pos, '"');
    if (!end) return false;
    
    size_t len = end - pos;
    if (len > max_len) return false;
    
    strncpy(out, pos, len);
    out[len] = '\0';
    return true;
}

static bool json_get_double(const char* json, const char* key, double* out) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":", key);
    
    const char* pos = strstr(json, search);
    if (!pos) return false;
    
    pos += strlen(search);
    while (*pos == ' ' || *pos == '\t') pos++;
    
    *out = atof(pos);
    return true;
}

static bool json_get_int(const char* json, const char* key, int* out) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":", key);
    
    const char* pos = strstr(json, search);
    if (!pos) return false;
    
    pos += strlen(search);
    while (*pos == ' ' || *pos == '\t') pos++;
    
    *out = atoi(pos);
    return true;
}

static bool json_get_uint64(const char* json, const char* key, uint64_t* out) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":", key);
    
    const char* pos = strstr(json, search);
    if (!pos) return false;
    
    pos += strlen(search);
    while (*pos == ' ' || *pos == '\t') pos++;
    
    *out = (uint64_t)atoll(pos);
    return true;
}

/* ============================================================================
 * Security Functions (from Day 2)
 * ========================================================================= */

int safe_copy_string(char* dest, const char* src, size_t max_len) {
    if (!dest || !src) return -1;
    
    size_t src_len = strnlen(src, max_len + 1);
    
    if (src_len > max_len) {
        fprintf(stderr, "Security: Input string exceeds buffer limit (%zu > %zu)\n", 
                src_len, max_len);
        return -1;
    }
    
    strncpy(dest, src, max_len);
    dest[max_len] = '\0';
    return 0;
}

int clamp_freq(int freq_mhz) {
    if (freq_mhz < GPU_FREQ_MIN_MHZ) return GPU_FREQ_MIN_MHZ;
    if (freq_mhz > GPU_FREQ_MAX_MHZ) return GPU_FREQ_MAX_MHZ;
    return freq_mhz;
}

int clamp_power(int power_w) {
    if (power_w < GPU_POWER_MIN_W) return GPU_POWER_MIN_W;
    if (power_w > GPU_POWER_MAX_W) return GPU_POWER_MAX_W;
    return power_w;
}

bool can_trigger_rule(const ea_rule_t* rule, uint64_t current_time_ms) {
    if (!rule) return false;
    
    uint64_t elapsed = current_time_ms - rule->last_triggered_ms;
    return elapsed >= rule->cooldown_ms;
}

/* ============================================================================
 * IR Validation
 * ========================================================================= */

int validate_ir(const ea_ir_t* ir) {
    if (!ir) return -1;
    
    /* Validate model_id length */
    if (strnlen(ir->model_id, MAX_ID_LEN + 1) > MAX_ID_LEN) {
        fprintf(stderr, "Validation: model_id exceeds maximum length\n");
        return -1;
    }
    
    /* Validate constraints */
    if (ir->constraints.power_cap_w <= 0 || ir->constraints.power_cap_w > 1000) {
        fprintf(stderr, "Validation: power_cap_w out of range (0, 1000]\n");
        return -1;
    }
    
    if (ir->constraints.latency_slo_ms <= 0 || ir->constraints.latency_slo_ms > 10000) {
        fprintf(stderr, "Validation: latency_slo_ms out of range (0, 10000]\n");
        return -1;
    }
    
    if (ir->constraints.quality_floor < 0 || ir->constraints.quality_floor > 1.0) {
        fprintf(stderr, "Validation: quality_floor out of range [0, 1]\n");
        return -1;
    }
    
    /* Validate rule count */
    if (ir->num_rules < 0 || ir->num_rules > MAX_RULES) {
        fprintf(stderr, "Validation: num_rules out of range [0, %d]\n", MAX_RULES);
        return -1;
    }
    
    /* Validate each rule */
    for (int i = 0; i < ir->num_rules; i++) {
        const ea_rule_t* rule = &ir->rules[i];
        
        /* Validate metric_name length */
        if (strnlen(rule->metric_name, MAX_METRIC_NAME_LEN + 1) > MAX_METRIC_NAME_LEN) {
            fprintf(stderr, "Validation: rule[%d] metric_name exceeds maximum length\n", i);
            return -1;
        }
        
        /* Validate action type */
        if (rule->action < ACTION_NONE || rule->action > ACTION_QUANTIZE) {
            fprintf(stderr, "Validation: rule[%d] invalid action type\n", i);
            return -1;
        }
        
        /* Validate cooldown */
        if (rule->cooldown_ms < 0) {
            fprintf(stderr, "Validation: rule[%d] invalid cooldown\n", i);
            return -1;
        }
    }
    
    return 0;
}

/* ============================================================================
 * IR Loading from JSON
 * ========================================================================= */

int ea_ir_from_json(const char* json_str, ea_ir_t* ir) {
    if (!json_str || !ir) return -1;
    
    memset(ir, 0, sizeof(ea_ir_t));
    
    /* Parse metadata */
    char model_id[MAX_ID_LEN + 1];
    if (!json_get_string(json_str, "model_id", model_id, MAX_ID_LEN)) {
        fprintf(stderr, "IR Load: Failed to parse model_id\n");
        return -1;
    }
    
    /* ✅ SECURITY: Safe string copy with length validation */
    if (safe_copy_string(ir->model_id, model_id, MAX_ID_LEN) != 0) {
        return -1;
    }
    
    if (!json_get_string(json_str, "ir_version", ir->ir_version, sizeof(ir->ir_version) - 1)) {
        strcpy(ir->ir_version, "0.1.0");
    }
    
    if (!json_get_uint64(json_str, "created_at", &ir->created_at)) {
        ir->created_at = 0;
    }
    
    /* Parse constraints */
    if (!json_get_double(json_str, "power_cap_w", &ir->constraints.power_cap_w)) {
        fprintf(stderr, "IR Load: Failed to parse power_cap_w\n");
        return -1;
    }
    
    if (!json_get_double(json_str, "latency_slo_ms", &ir->constraints.latency_slo_ms)) {
        fprintf(stderr, "IR Load: Failed to parse latency_slo_ms\n");
        return -1;
    }
    
    if (!json_get_double(json_str, "quality_floor", &ir->constraints.quality_floor)) {
        fprintf(stderr, "IR Load: Failed to parse quality_floor\n");
        return -1;
    }
    
    /* Parse cost model */
    json_get_double(json_str, "flops_per_token", &ir->cost_model.flops_per_token);
    json_get_double(json_str, "mem_bw_per_token", &ir->cost_model.mem_bw_per_token);
    json_get_double(json_str, "alpha", &ir->cost_model.alpha);
    json_get_double(json_str, "beta", &ir->cost_model.beta);
    json_get_double(json_str, "overhead_j", &ir->cost_model.overhead_j);
    
    /* Parse runtime config */
    json_get_int(json_str, "dvfs_granularity", &ir->dvfs_granularity);
    json_get_int(json_str, "telemetry_interval_ms", &ir->telemetry_interval_ms);
    json_get_int(json_str, "recompile_limit", &ir->recompile_limit);
    
    /* Parse rules (simplified for v0.1) */
    if (!json_get_int(json_str, "num_rules", &ir->num_rules)) {
        ir->num_rules = 0;
    }
    
    /* For v0.1, we'll parse the first rule manually */
    /* In production, use a proper JSON library */
    if (ir->num_rules > 0) {
        const char* rules_start = strstr(json_str, "\"rules\":");
        if (rules_start) {
            /* Parse first rule */
            char metric_name[MAX_METRIC_NAME_LEN + 1];
            if (json_get_string(rules_start, "metric_name", metric_name, MAX_METRIC_NAME_LEN)) {
                safe_copy_string(ir->rules[0].metric_name, metric_name, MAX_METRIC_NAME_LEN);
            }
            
            char op[4];
            if (json_get_string(rules_start, "op", op, 3)) {
                strncpy(ir->rules[0].op, op, 3);
                ir->rules[0].op[3] = '\0';
            }
            
            json_get_double(rules_start, "threshold", &ir->rules[0].threshold);
            
            int action;
            if (json_get_int(rules_start, "action", &action)) {
                ir->rules[0].action = (ea_action_type_t)action;
            }
            
            json_get_double(rules_start, "action_param", &ir->rules[0].action_param);
            json_get_double(rules_start, "min_value", &ir->rules[0].min_value);
            json_get_double(rules_start, "max_value", &ir->rules[0].max_value);
            
            uint64_t cooldown;
            if (json_get_uint64(rules_start, "cooldown_ms", &cooldown)) {
                ir->rules[0].cooldown_ms = cooldown;
            }
            
            ir->rules[0].last_triggered_ms = 0;
        }
    }
    
    /* ✅ SECURITY: Validate loaded IR */
    if (validate_ir(ir) != 0) {
        fprintf(stderr, "IR Load: Validation failed\n");
        return -1;
    }
    
    return 0;
}

/* ============================================================================
 * IR Loading from File
 * ========================================================================= */

int ea_ir_load_from_file(const char* filename, ea_ir_t* ir) {
    if (!filename || !ir) return -1;
    
    FILE* f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "IR Load: Failed to open file: %s\n", filename);
        return -1;
    }
    
    /* Get file size */
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    /* ✅ SECURITY: Limit file size to prevent memory exhaustion */
    if (size > 1024 * 1024) {  // 1MB limit
        fprintf(stderr, "IR Load: File too large (> 1MB)\n");
        fclose(f);
        return -1;
    }
    
    /* Read file */
    char* json_str = (char*)malloc(size + 1);
    if (!json_str) {
        fprintf(stderr, "IR Load: Memory allocation failed\n");
        fclose(f);
        return -1;
    }
    
    size_t read = fread(json_str, 1, size, f);
    json_str[read] = '\0';
    fclose(f);
    
    /* Parse JSON */
    int result = ea_ir_from_json(json_str, ir);
    
    free(json_str);
    return result;
}

/* ============================================================================
 * Utility Functions
 * ========================================================================= */

const char* ea_action_type_name(ea_action_type_t action) {
    switch (action) {
        case ACTION_NONE: return "NONE";
        case ACTION_DVFS_SCALE: return "DVFS_SCALE";
        case ACTION_MOE_REDUCE_K: return "MOE_REDUCE_K";
        case ACTION_LAYER_SKIP: return "LAYER_SKIP";
        case ACTION_BATCH_RESIZE: return "BATCH_RESIZE";
        case ACTION_QUANTIZE: return "QUANTIZE";
        default: return "UNKNOWN";
    }
}

void ea_ir_print(const ea_ir_t* ir) {
    if (!ir) return;
    
    printf("=== EA-AOL IR ===\n");
    printf("Model: %s\n", ir->model_id);
    printf("Version: %s\n", ir->ir_version);
    printf("Created: %llu\n", (unsigned long long)ir->created_at);
    
    printf("\nConstraints:\n");
    printf("  Power Cap: %.1f W\n", ir->constraints.power_cap_w);
    printf("  Latency SLO: %.1f ms\n", ir->constraints.latency_slo_ms);
    printf("  Quality Floor: %.2f\n", ir->constraints.quality_floor);
    
    printf("\nCost Model:\n");
    printf("  FLOPs/token: %.2e\n", ir->cost_model.flops_per_token);
    printf("  Mem BW/token: %.2e bytes\n", ir->cost_model.mem_bw_per_token);
    printf("  Alpha: %.2e J/FLOP\n", ir->cost_model.alpha);
    printf("  Beta: %.2e J/Byte\n", ir->cost_model.beta);
    
    printf("\nRules: %d\n", ir->num_rules);
    for (int i = 0; i < ir->num_rules; i++) {
        const ea_rule_t* rule = &ir->rules[i];
        printf("  [%d] %s %s %.1f -> %s (cooldown: %llu ms)\n",
               i, rule->metric_name, rule->op, rule->threshold,
               ea_action_type_name(rule->action),
               (unsigned long long)rule->cooldown_ms);
    }
    
    printf("=================\n");
}
