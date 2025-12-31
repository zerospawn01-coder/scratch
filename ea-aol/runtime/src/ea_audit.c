#include "ea_audit.h"
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <unistd.h>


static ea_audit_buffer_t _auditor_state = {0};

/* Jules Hygiene Guard: Safe Write Wrapper */
static ssize_t safe_write(int fd, const void *buf, size_t count) {
  size_t written = 0;
  const uint8_t *p = (const uint8_t *)buf;
  while (written < count) {
    ssize_t res = write(fd, p + written, count - written);
    if (res < 0) {
      if (errno == EINTR)
        continue;
      return -1;
    }
    written += res;
  }
  return written;
}

int ea_audit_init(const char *log_file) {
  /* Jules: Protect against FD leak on re-init */
  if (_auditor_state.fd > 0) {
    close(_auditor_state.fd);
  }

  _auditor_state.fd = open(log_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  _auditor_state.head = 0;
  _auditor_state.dirty = false;
  _auditor_state.last_flushed_pwr_state = (ea_power_state_t)-1;

  return (_auditor_state.fd >= 0) ? 0 : -1;
}

void ea_audit_flush(void) {
  if (!_auditor_state.dirty || _auditor_state.fd < 0)
    return;

  uint32_t count = _auditor_state.head;
  if (count == 0)
    return;

  if (safe_write(_auditor_state.fd, _auditor_state.records,
                 sizeof(ea_audit_record_t) * count) < 0) {
    // Fallback: Report to stderr if disk full/IO error
  }

  /* Jules: Ensure physical persistence during critical transitions */
  fdatasync(_auditor_state.fd);

  _auditor_state.dirty = false;
  _auditor_state.head = 0;
}

void ea_audit_log_decision(const ea_audit_record_t *record) {
  if (record == NULL)
    return;

  _auditor_state.records[_auditor_state.head] = *record;
  _auditor_state.head = (_auditor_state.head + 1) % EA_AUDIT_RING_SIZE;
  _auditor_state.dirty = true;

  /* Jules: Strategy-based flushing */
  bool should_flush =
      (record->pwr_state != (uint32_t)_auditor_state.last_flushed_pwr_state) ||
      (record->pwr_state == EA_POWER_CRITICAL) || (_auditor_state.head == 0);

  if (should_flush) {
    ea_audit_flush();
    _auditor_state.last_flushed_pwr_state = (ea_power_state_t)record->pwr_state;
  }
}
