/*
 * simple_client.c - EA-AOL Simple C Client Example
 * License: BSD-2-Clause
 * 
 * Demonstrates basic usage of EA-AOL C API
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ea_aol.h"

// Sample EA-AOL YAML (embedded as string)
static const char* SAMPLE_YAML = 
"inference:\n"
"  model_id: \"llama-2-7b\"\n"
"  power_cap: 100W\n"
"  latency_slo_ms: 50\n"
"  quality_floor: 0.90\n"
"  orchestrator:\n"
"    layers: [\"sparse\"]\n"
"    monitoring: [\"EPI\"]\n";

int main(int argc, char* argv[]) {
    printf("==========================================================\n");
    printf("EA-AOL Simple Client Example\n");
    printf("Version: %s\n", ea_aol_version());
    printf("==========================================================\n\n");
    
    // 1. Initialize runtime
    printf("[1] Initializing EA-AOL runtime...\n");
    ea_aol_ctx_t* ctx = ea_aol_init(NULL);
    if (!ctx) {
        fprintf(stderr, "Error: Failed to initialize runtime\n");
        return 1;
    }
    printf("    Runtime initialized successfully\n\n");
    
    // 2. Prepare inference request
    printf("[2] Preparing inference request...\n");
    ea_inference_req_t req;
    req.request_id = "req-001";
    req.yaml_payload = SAMPLE_YAML;
    req.timeout_ms = 10000;
    
    printf("    Request ID: %s\n", req.request_id);
    printf("    Timeout: %llu ms\n", (unsigned long long)req.timeout_ms);
    printf("\n");
    
    // 3. Schedule inference
    printf("[3] Scheduling inference...\n");
    int result = ea_aol_schedule(ctx, &req);
    if (result != 0) {
        fprintf(stderr, "Error: Failed to schedule inference (code: %d)\n", result);
        ea_aol_shutdown(ctx);
        return 1;
    }
    printf("    Inference scheduled successfully\n\n");
    
    // 4. Get status
    printf("[4] Getting status...\n");
    ea_status_t status;
    result = ea_aol_get_status(ctx, req.request_id, &status);
    if (result != 0) {
        fprintf(stderr, "Error: Failed to get status (code: %d)\n", result);
        ea_aol_shutdown(ctx);
        return 1;
    }
    
    printf("    State: %d ", status.state);
    switch (status.state) {
        case 0: printf("(PENDING)\n"); break;
        case 1: printf("(RUNNING)\n"); break;
        case 2: printf("(DONE)\n"); break;
        case 3: printf("(FAILED)\n"); break;
        default: printf("(UNKNOWN)\n"); break;
    }
    printf("    EPI: %.4f J/token\n", status.epi_j_per_token);
    printf("    Power: %.2f W\n", status.current_power_w);
    printf("    Latency (P99): %.2f ms\n", status.p99_latency_ms);
    printf("\n");
    
    // 5. Simulate feedback
    printf("[5] Sending feedback...\n");
    const char* feedback_json = "{\"metric\":\"EPI\",\"value\":0.12}";
    result = ea_aol_feedback(ctx, feedback_json);
    if (result != 0) {
        fprintf(stderr, "Warning: Failed to send feedback (code: %d)\n", result);
    } else {
        printf("    Feedback sent successfully\n");
    }
    printf("\n");
    
    // 6. Get compiled IR
    printf("[6] Retrieving compiled IR...\n");
    char ir_buffer[4096];
    result = ea_aol_get_ir(ctx, req.request_id, ir_buffer, sizeof(ir_buffer));
    if (result == 0) {
        printf("    IR (truncated):\n");
        printf("    %s\n", ir_buffer);
    } else {
        fprintf(stderr, "Warning: Failed to get IR (code: %d)\n", result);
    }
    printf("\n");
    
    // 7. Shutdown
    printf("[7] Shutting down runtime...\n");
    ea_aol_shutdown(ctx);
    printf("    Runtime shutdown complete\n\n");
    
    printf("==========================================================\n");
    printf("Example completed successfully!\n");
    printf("==========================================================\n");
    
    return 0;
}
