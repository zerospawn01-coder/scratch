/*
 * ea_aol_runtime.cpp - EA-AOL Runtime Core Implementation
 * License: BSD-2-Clause
 * Version: 0.1.0
 */

#include "../include/ea_aol.h"
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <mutex>
#include <chrono>
#include <fstream>
#include <sstream>

// JSON parsing (simple implementation, use nlohmann/json in production)
#include <cstring>

namespace ea_aol {

// Internal task state
struct Task {
    std::string request_id;
    std::string yaml_payload;
    std::string ir_json;
    ea_status_t status;
    std::chrono::system_clock::time_point created_at;
    std::chrono::system_clock::time_point started_at;
    int recompile_count;
};

// Runtime context implementation
struct ea_aol_ctx_t {
    std::string config_path;
    std::map<std::string, Task> tasks;
    std::mutex tasks_mutex;
    bool debug_mode;
    
    ea_aol_ctx_t() : debug_mode(false) {}
};

} // namespace ea_aol

using namespace ea_aol;

// ============================================================================
// Lifecycle Functions
// ============================================================================

ea_aol_ctx_t* ea_aol_init(const char* config_path) {
    auto* ctx = new ea_aol_ctx_t();
    
    if (config_path) {
        ctx->config_path = config_path;
        std::cout << "[Runtime] Initialized with config: " << config_path << std::endl;
    } else {
        std::cout << "[Runtime] Initialized with default config" << std::endl;
    }
    
    return ctx;
}

void ea_aol_shutdown(ea_aol_ctx_t* ctx) {
    if (!ctx) return;
    
    std::cout << "[Runtime] Shutting down..." << std::endl;
    std::cout << "[Runtime] Processed " << ctx->tasks.size() << " tasks" << std::endl;
    
    delete ctx;
}

// ============================================================================
// Core Operations
// ============================================================================

int ea_aol_schedule(ea_aol_ctx_t* ctx, const ea_inference_req_t* req) {
    if (!ctx || !req) return -1;
    if (!req->request_id || !req->yaml_payload) return -1;
    
    std::lock_guard<std::mutex> lock(ctx->tasks_mutex);
    
    std::cout << "[Runtime] Scheduling request: " << req->request_id << std::endl;
    
    // Check for duplicate request_id
    if (ctx->tasks.find(req->request_id) != ctx->tasks.end()) {
        std::cerr << "[Runtime] Error: Duplicate request_id: " << req->request_id << std::endl;
        return -2;
    }
    
    // Create task
    Task task;
    task.request_id = req->request_id;
    task.yaml_payload = req->yaml_payload;
    task.created_at = std::chrono::system_clock::now();
    task.recompile_count = 0;
    
    // Initialize status
    task.status.state = 0; // PENDING
    task.status.epi_j_per_token = 0.0;
    task.status.current_power_w = 0.0;
    task.status.p99_latency_ms = 0.0;
    
    // Simulate compilation (in real implementation, call compiler)
    std::cout << "[Runtime] Compiling EA-AOL YAML..." << std::endl;
    task.ir_json = "{\"ir_version\":\"0.1.0\",\"meta\":{\"model_id\":\"test\"}}";
    
    // Move to RUNNING state
    task.status.state = 1; // RUNNING
    task.started_at = std::chrono::system_clock::now();
    task.status.current_power_w = 120.0; // Simulated baseline power
    
    ctx->tasks[req->request_id] = task;
    
    std::cout << "[Runtime] Request " << req->request_id << " is now RUNNING" << std::endl;
    
    return 0; // Success
}

int ea_aol_get_status(ea_aol_ctx_t* ctx, const char* request_id, ea_status_t* out_status) {
    if (!ctx || !request_id || !out_status) return -1;
    
    std::lock_guard<std::mutex> lock(ctx->tasks_mutex);
    
    auto it = ctx->tasks.find(request_id);
    if (it == ctx->tasks.end()) {
        return -1; // Not found
    }
    
    *out_status = it->second.status;
    return 0;
}

int ea_aol_feedback(ea_aol_ctx_t* ctx, const char* metric_json) {
    if (!ctx || !metric_json) return -1;
    
    std::cout << "[Runtime] Received feedback: " << metric_json << std::endl;
    
    // In real implementation, parse JSON and update task status
    // For now, just acknowledge
    
    return 0;
}

// ============================================================================
// Extended Functions (Beyond Basic API)
// ============================================================================

int ea_aol_cancel(ea_aol_ctx_t* ctx, const char* request_id) {
    if (!ctx || !request_id) return -1;
    
    std::lock_guard<std::mutex> lock(ctx->tasks_mutex);
    
    auto it = ctx->tasks.find(request_id);
    if (it == ctx->tasks.end()) {
        return -1; // Not found
    }
    
    it->second.status.state = 5; // CANCELLED
    std::cout << "[Runtime] Cancelled request: " << request_id << std::endl;
    
    return 0;
}

int ea_aol_get_ir(ea_aol_ctx_t* ctx, const char* request_id, char* out_json, size_t out_size) {
    if (!ctx || !request_id || !out_json || out_size == 0) return -1;
    
    std::lock_guard<std::mutex> lock(ctx->tasks_mutex);
    
    auto it = ctx->tasks.find(request_id);
    if (it == ctx->tasks.end()) {
        return -1; // Not found
    }
    
    const std::string& ir = it->second.ir_json;
    if (ir.size() >= out_size) {
        return -2; // Buffer too small
    }
    
    std::strncpy(out_json, ir.c_str(), out_size - 1);
    out_json[out_size - 1] = '\0';
    
    return 0;
}

void ea_aol_set_debug(ea_aol_ctx_t* ctx, int enable) {
    if (!ctx) return;
    ctx->debug_mode = (enable != 0);
    std::cout << "[Runtime] Debug mode: " << (ctx->debug_mode ? "ON" : "OFF") << std::endl;
}

// ============================================================================
// Utility Functions
// ============================================================================

const char* ea_aol_version(void) {
    return "0.1.0";
}

const char* ea_aol_error_string(ea_aol_error_t error) {
    switch (error) {
        case EA_AOL_OK: return "Success";
        case EA_AOL_ERR_INVALID_PARAM: return "Invalid parameter";
        case EA_AOL_ERR_INVALID_YAML: return "Invalid YAML";
        case EA_AOL_ERR_COMPILATION_FAILED: return "Compilation failed";
        case EA_AOL_ERR_SCHEDULE_FAILED: return "Scheduling failed";
        case EA_AOL_ERR_NOT_FOUND: return "Request not found";
        case EA_AOL_ERR_TIMEOUT: return "Timeout";
        case EA_AOL_ERR_POWER_CAP_EXCEEDED: return "Power cap exceeded";
        case EA_AOL_ERR_QUALITY_FLOOR_VIOLATED: return "Quality floor violated";
        case EA_AOL_ERR_HARDWARE_UNAVAILABLE: return "Hardware unavailable";
        case EA_AOL_ERR_OUT_OF_MEMORY: return "Out of memory";
        case EA_AOL_ERR_INTERNAL: return "Internal error";
        default: return "Unknown error";
    }
}
