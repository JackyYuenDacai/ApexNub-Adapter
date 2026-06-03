#ifndef REPORT_TIMER_H
#define REPORT_TIMER_H

#include <stdint.h>
#include <string.h>
#include <math.h>
#include "nordic_common.h"
#include "nrf.h"
#include "nrf_soc.h"
#include "app_error.h"
#include "nrf_log.h"
#include "app_timer.h"
#include "nrf_drv_timer.h"
#include "ble_config.h"
 
 
#include "ble_cmd_service.h"
 
void hid_report_tick_init(void);
void hid_report_tick_enable(void);
void hid_report_tick_disable(void);
extern uint8_t is_able_to_send_report;
#endif
