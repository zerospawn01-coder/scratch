#include "ea_interrupt.h"
#include <assert.h>
#include <stdatomic.h>
#include <stddef.h>


#define EA_MAX_SUBSCRIBERS 8

static atomic_int _sub_count = 0;
static ea_metabolic_callback_t _subscribers[EA_MAX_SUBSCRIBERS];
static atomic_int _current_internal_state = EA_POWER_GRID_STABLE;

/* 割り込みハンドラの登録 */
int ea_interrupt_subscribe(ea_metabolic_callback_t cb) {
  /* Jules Safety Guard: Bounds checking and thread-safe registration */
  int current = atomic_load(&_sub_count);

  if (current >= EA_MAX_SUBSCRIBERS) {
    return -1; // Buffer full (Security: Do not overflow function pointers)
  }

  if (cb == NULL)
    return -1;

  _subscribers[current] = cb;
  atomic_fetch_add(&_sub_count, 1);

  return 0;
}

/* 割り込み配信（HALから呼ばれる、あるいは監視スレッドから呼ばれる） */
void ea_dispatch_power_interrupt(ea_power_interrupt_t *interrupt) {
  if (interrupt == NULL)
    return;

  /* Jules: Safety fallback for unknown states */
  if (interrupt->state == EA_POWER_UNKNOWN) {
    interrupt->state = EA_POWER_BATTERY;
  }

  /* Jules: Atomic state update for thread visibility */
  atomic_store(&_current_internal_state, (int)interrupt->state);

  /* 全サブスクライバ（代謝コントローラ）へ通知 */
  int count = atomic_load(&_sub_count);
  for (int i = 0; i < count; i++) {
    if (_subscribers[i]) {
      _subscribers[i](interrupt);
    }
  }
}
