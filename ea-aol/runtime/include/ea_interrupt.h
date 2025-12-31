/**
 * EA-AOL Power Interrupt API v0.3
 */
#ifndef EA_INTERRUPT_H
#define EA_INTERRUPT_H

#include "ea_hal_power.h"
#include <time.h>

/**
 * Power Interrupt Event (代謝変更のトリガー)
 */
typedef struct {
    ea_power_state_t state;
    double current_wattage;      /* 現在の消費電力 */
    double battery_capacity;     /* 残量(%) */
    struct timespec timestamp;   /* 発生時刻 */
    
    /* 予測される継続時間(秒)。不明な場合は-1.0。*/
    double expected_duration;    
} ea_power_interrupt_t;

/**
 * Runtime Callback (AIモデル層が登録する「代謝制御」関数)
 */
typedef void (*ea_metabolic_callback_t)(const ea_power_interrupt_t* interrupt);

/* 保持するサブスクライバ登録 */
int ea_interrupt_subscribe(ea_metabolic_callback_t cb);

/* 割り込み配信（HALから呼ばれる） */
void ea_dispatch_power_interrupt(ea_power_interrupt_t* interrupt);

#endif /* EA_INTERRUPT_H */
