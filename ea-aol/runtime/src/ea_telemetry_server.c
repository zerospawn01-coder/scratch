/*
 * ea_telemetry_server.c - Unix Domain Socket Telemetry Server
 *
 * License: BSD-2-Clause
 * Version: 0.1.0
 *
 * Provides real-time telemetry streaming via Unix Domain Socket.
 * This is the "nervous system" that connects runtime to monitoring.
 *
 * Design Philosophy:
 * - Non-blocking: Doesn't interfere with inference loop
 * - Asynchronous: Separate thread for telemetry
 * - Standard: Uses Unix Domain Socket (like Docker/Kubernetes)
 * - Bidirectional: Can receive commands in future
 */

#include "ea_telemetry_server.h"
#include "ea_metrics.h"
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


#ifdef _WIN32
/* Windows named pipe implementation */
#include <windows.h>
#define SOCKET_PATH "\\\\.\\pipe\\ea_aol"
#else
/* Unix domain socket implementation */
#include <sys/socket.h>
#include <sys/un.h>
#define SOCKET_PATH "/tmp/ea_aol.sock"
#endif

/* ============================================================================
 * Telemetry Server Context
 * ========================================================================= */

struct ea_telemetry_server_t {
  /* Thread control */
  pthread_t thread;
  volatile int running;

  /* Socket */
#ifdef _WIN32
  HANDLE pipe_handle;
#else
  int server_fd;
#endif

  /* Metrics snapshot (thread-safe copy) */
  pthread_mutex_t mutex;
  telemetry_snapshot_t current_snapshot;

  /* Configuration */
  int update_interval_ms;
};

/* ============================================================================
 * Snapshot Management
 * ========================================================================= */

void ea_telemetry_server_update_snapshot(ea_telemetry_server_t *server,
                                         const telemetry_snapshot_t *snapshot) {
  if (!server || !snapshot)
    return;

  pthread_mutex_lock(&server->mutex);
  memcpy(&server->current_snapshot, snapshot, sizeof(telemetry_snapshot_t));
  pthread_mutex_unlock(&server->mutex);
}

static void get_snapshot_copy(ea_telemetry_server_t *server,
                              telemetry_snapshot_t *snapshot) {
  pthread_mutex_lock(&server->mutex);
  memcpy(snapshot, &server->current_snapshot, sizeof(telemetry_snapshot_t));
  pthread_mutex_unlock(&server->mutex);
}

/* ============================================================================
 * JSON Formatting
 * ========================================================================= */

static int format_telemetry_json(const telemetry_snapshot_t *snapshot,
                                 char *buffer, size_t buffer_size) {
  return snprintf(buffer, buffer_size,
                  "{"
                  "\"timestamp_ms\":%llu,"
                  "\"power_w\":%.2f,"
                  "\"temp_c\":%.1f,"
                  "\"freq_mhz\":%.0f,"
                  "\"util\":%.3f,"
                  "\"throughput_tps\":%.2f,"
                  "\"epi_j_per_token\":%.4f,"
                  "\"latency_ms\":%.2f,"
                  "\"quality\":%.3f,"
                  "\"active_k\":%d,"
                  "\"violation\":\"%s\","
                  "\"action\":\"%s\""
                  "}\n",
                  (unsigned long long)snapshot->timestamp_ms, snapshot->power_w,
                  snapshot->temp_c, snapshot->freq_mhz, snapshot->utilization,
                  snapshot->throughput_tps, snapshot->epi_j_per_token,
                  snapshot->latency_ms, snapshot->quality, snapshot->active_k,
                  snapshot->violation ? snapshot->violation : "none",
                  snapshot->current_action ? snapshot->current_action : "none");
}

/* ============================================================================
 * Server Thread (Unix)
 * ========================================================================= */

#ifndef _WIN32

static void *telemetry_thread_unix(void *arg) {
  ea_telemetry_server_t *server = (ea_telemetry_server_t *)arg;
  struct sockaddr_un addr;

  printf("[Telemetry] Starting Unix domain socket server...\n");

  /* Create socket */
  server->server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (server->server_fd < 0) {
    fprintf(stderr, "[Telemetry] Error: Failed to create socket\n");
    return NULL;
  }

  /* Setup address */
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

  /* Remove old socket file */
  unlink(SOCKET_PATH);

  /* Bind */
  if (bind(server->server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    fprintf(stderr, "[Telemetry] Error: Failed to bind socket: %s\n",
            strerror(errno));
    close(server->server_fd);
    return NULL;
  }

  /* Listen */
  if (listen(server->server_fd, 5) < 0) {
    fprintf(stderr, "[Telemetry] Error: Failed to listen: %s\n",
            strerror(errno));
    close(server->server_fd);
    return NULL;
  }

  printf("[Telemetry] Listening on %s\n", SOCKET_PATH);

  /* Accept and stream loop */
  while (server->running) {
    int client_fd = accept(server->server_fd, NULL, NULL);
    if (client_fd < 0) {
      if (server->running) {
        fprintf(stderr, "[Telemetry] Warning: Accept failed: %s\n",
                strerror(errno));
      }
      continue;
    }

    printf("[Telemetry] Client connected\n");

    /* Stream telemetry to client */
    while (server->running) {
      telemetry_snapshot_t snapshot;
      get_snapshot_copy(server, &snapshot);

      char buffer[512];
      int len = format_telemetry_json(&snapshot, buffer, sizeof(buffer));

      if (write(client_fd, buffer, len) < 0) {
        printf("[Telemetry] Client disconnected\n");
        break;
      }

      /* Sleep for update interval */
      usleep(server->update_interval_ms * 1000);
    }

    close(client_fd);
  }

  close(server->server_fd);
  unlink(SOCKET_PATH);

  printf("[Telemetry] Server stopped\n");
  return NULL;
}

#else

/* ============================================================================
 * Server Thread (Windows Named Pipe)
 * ========================================================================= */

static void *telemetry_thread_windows(void *arg) {
  ea_telemetry_server_t *server = (ea_telemetry_server_t *)arg;

  printf("[Telemetry] Starting Windows named pipe server...\n");

  while (server->running) {
    /* Create named pipe */
    server->pipe_handle =
        CreateNamedPipeA(SOCKET_PATH, PIPE_ACCESS_OUTBOUND,
                         PIPE_TYPE_MESSAGE | PIPE_WAIT, 1, 512, 512, 0, NULL);

    if (server->pipe_handle == INVALID_HANDLE_VALUE) {
      fprintf(stderr, "[Telemetry] Error: Failed to create named pipe\n");
      return NULL;
    }

    printf("[Telemetry] Waiting for client on %s\n", SOCKET_PATH);

    /* Wait for client */
    if (!ConnectNamedPipe(server->pipe_handle, NULL)) {
      CloseHandle(server->pipe_handle);
      continue;
    }

    printf("[Telemetry] Client connected\n");

    /* Stream telemetry */
    while (server->running) {
      telemetry_snapshot_t snapshot;
      get_snapshot_copy(server, &snapshot);

      char buffer[512];
      DWORD len = format_telemetry_json(&snapshot, buffer, sizeof(buffer));
      DWORD written;

      if (!WriteFile(server->pipe_handle, buffer, len, &written, NULL)) {
        printf("[Telemetry] Client disconnected\n");
        break;
      }

      Sleep(server->update_interval_ms);
    }

    DisconnectNamedPipe(server->pipe_handle);
    CloseHandle(server->pipe_handle);
  }

  printf("[Telemetry] Server stopped\n");
  return NULL;
}

#endif

/* ============================================================================
 * Public API
 * ========================================================================= */

ea_telemetry_server_t *ea_telemetry_server_create(int update_interval_ms) {
  ea_telemetry_server_t *server =
      (ea_telemetry_server_t *)malloc(sizeof(ea_telemetry_server_t));

  if (!server)
    return NULL;

  memset(server, 0, sizeof(ea_telemetry_server_t));
  server->update_interval_ms = update_interval_ms;
  server->running = 0;

  pthread_mutex_init(&server->mutex, NULL);

  return server;
}

int ea_telemetry_server_start(ea_telemetry_server_t *server) {
  if (!server || server->running)
    return -1;

  server->running = 1;

#ifdef _WIN32
  int result =
      pthread_create(&server->thread, NULL, telemetry_thread_windows, server);
#else
  int result =
      pthread_create(&server->thread, NULL, telemetry_thread_unix, server);
#endif

  if (result != 0) {
    fprintf(stderr, "[Telemetry] Error: Failed to create thread\n");
    server->running = 0;
    return -1;
  }

  return 0;
}

void ea_telemetry_server_stop(ea_telemetry_server_t *server) {
  if (!server || !server->running)
    return;

  printf("[Telemetry] Stopping server...\n");

  server->running = 0;

  /* Wait for thread to finish */
  pthread_join(server->thread, NULL);
}

void ea_telemetry_server_destroy(ea_telemetry_server_t *server) {
  if (!server)
    return;

  if (server->running) {
    ea_telemetry_server_stop(server);
  }

  pthread_mutex_destroy(&server->mutex);
  free(server);
}
