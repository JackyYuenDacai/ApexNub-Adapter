#ifndef BLE_CONFIG_H
#define BLE_CONFIG_H

#include <stdint.h>
#include <string.h>
#include "nordic_common.h"
#include "nrf.h"
#include "nrf_sdm.h"
#include "app_error.h"
#include "ble.h"
#include "ble_err.h"
#include "ble_hci.h"
#include "ble_srv_common.h"
#include "ble_advdata.h"
#include "ble_hids.h"
#include "ble_bas.h"
#include "ble_dis.h"
#include "ble_conn_params.h"
#include "sensorsim.h"
#include "bsp_btn_ble.h"
#include "app_scheduler.h"
#include "nrf_sdh.h"
#include "nrf_sdh_soc.h"
#include "nrf_sdh_ble.h"
#include "app_timer.h"
#include "peer_manager.h"
#include "ble_advertising.h"
#include "fds.h"
#include "ble_conn_state.h"
#include "nrf_ble_gatt.h"
#include "nrf_ble_qwr.h"
#include "nrf_pwr_mgmt.h"
#include "peer_manager_handler.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"


#include "ble_conn_state.h"
#include "nrf_sdh.h"
#include "nrf_sdh_ble.h"
#include "nrf_fstorage_sd.h"

 
#include "ble_cmd_service.h"
#include "report_timer.h"
 
#include "nrf_drv_rng.h"

#ifdef __cplusplus
extern "C" {
#endif
 





#define IS_SRVC_CHANGED_CHARACT_PRESENT 1                                          /**< Include or not the service_changed characteristic. if not enabled, the server's database cannot be changed for the lifetime of the device*/


#define DEVICE_NAME                     "ApexNub-Adapter"                             /**< Name of device. Will be included in the advertising data. */
#define MANUFACTURER_NAME               "DC JY"                      /**< Manufacturer. Will be passed to Device Information Service. */

#define APP_BLE_OBSERVER_PRIO           3                                           /**< Application's BLE observer priority. You shouldn't need to modify this value. */
#define APP_BLE_CONN_CFG_TAG            1                                           /**< A tag identifying the SoftDevice BLE configuration. */


#define APP_TIMER_PRESCALER             0                                          /**< Value of the RTC1 PRESCALER register. */
#define APP_TIMER_OP_QUEUE_SIZE         4                                          /**< Size of timer operation queues. */

#define BATTERY_LEVEL_MEAS_INTERVAL     APP_TIMER_TICKS(5000) /**< Battery level measurement interval (ticks). */
#define MIN_BATTERY_LEVEL               81                                         /**< Minimum simulated battery level. */
#define MAX_BATTERY_LEVEL               100                                        /**< Maximum simulated battery level. */
#define BATTERY_LEVEL_INCREMENT         1                                          /**< Increment between each simulated battery level measurement. */

#define PNP_ID_VENDOR_ID_SOURCE         0x01                                       /**< Vendor ID Source. */
#define PNP_ID_VENDOR_ID                0xADCF                                  /**< Vendor ID. */
#define PNP_ID_PRODUCT_ID               0xADCF                                      /**< Product ID. */
#define PNP_ID_PRODUCT_VERSION          0x0100                                     /**< Product Version. */

/*lint -emacro(524, MIN_CONN_INTERVAL) // Loss of precision */
#define MIN_CONN_INTERVAL               MSEC_TO_UNITS(7.5, UNIT_1_25_MS)             /**< Minimum connection interval (10 ms). */
#define MAX_CONN_INTERVAL               MSEC_TO_UNITS(15, UNIT_1_25_MS)             /**< Maximum connection interval (20 ms). */
#define SLAVE_LATENCY                   0                                            /**< Slave latency. */
#define CONN_SUP_TIMEOUT                MSEC_TO_UNITS(4000, UNIT_10_MS)             /**< Connection supervisory timeout (4000 ms). */
 
#define FIRST_CONN_PARAMS_UPDATE_DELAY  APP_TIMER_TICKS(5000)                       /**< Time from initiating event (connect or start of notification) to first time sd_ble_gap_conn_param_update is called (5 seconds). */
#define NEXT_CONN_PARAMS_UPDATE_DELAY   APP_TIMER_TICKS(30000)                      /**< Time between each call to sd_ble_gap_conn_param_update after the first call (30 seconds). */
#define MAX_CONN_PARAM_UPDATE_COUNT     3                                           /**< Number of attempts before giving up the connection parameter negotiation. */

#define SEC_PARAM_BOND                  1                                           /**< Perform bonding. */
#define SEC_PARAM_MITM                  0                                           /**< Man In The Middle protection required. */
#define SEC_PARAM_LESC                  0                                           /**< LE Secure Connections enabled. */
#define SEC_PARAM_KEYPRESS              0                                           /**< Keypress notifications not enabled. */
#define SEC_PARAM_IO_CAPABILITIES       BLE_GAP_IO_CAPS_DISPLAY_ONLY                /**< Display Only I/O capabilities. */
#define SEC_PARAM_OOB                   0                                           /**< Out Of Band data not available. */
#define SEC_PARAM_MIN_KEY_SIZE          7                                           /**< Minimum encryption key size. */
#define SEC_PARAM_MAX_KEY_SIZE          16                                          /**< Maximum encryption key size. */





#define SCHED_MAX_EVENT_DATA_SIZE       APP_TIMER_SCHED_EVENT_DATA_SIZE             /**< Maximum size of scheduler events. */
#ifdef SVCALL_AS_NORMAL_FUNCTION
#define SCHED_QUEUE_SIZE                20                                          /**< Maximum number of events in the scheduler queue. More is needed in case of Serialization. */
#else
#define SCHED_QUEUE_SIZE                30                                          /**< Maximum number of events in the scheduler queue. */
#endif

#define DEAD_BEEF                       0xDEADBEEF                                                /**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */

#define APP_FEATURE_NOT_SUPPORTED       BLE_GATT_STATUS_ATTERR_APP_BEGIN + 2                      /**< Reply when unsupported features are requested. */

#define APP_ADV_FAST_INTERVAL           0x0028                                      /**< Fast advertising interval (in units of 0.625 ms. This value corresponds to 25 ms.). */
#define APP_ADV_SLOW_INTERVAL           0x00A0                                      /**< Slow advertising interval (in units of 0.625 ms. This value corresponds to 100 ms.). */

#define APP_ADV_FAST_DURATION           3000                                        /**< The advertising duration of fast advertising in units of 10 milliseconds. */
#define APP_ADV_SLOW_DURATION           18000                                       /**< The advertising duration of slow advertising in units of 10 milliseconds. */

#define RANDOM_BUFF_SIZE    16      /**< Random numbers buffer size. */


extern pm_peer_id_t m_peer_id; /**< Device reference handle to the current bonded central. */
extern uint32_t m_whitelist_peer_cnt;                                    /**< Number of peers currently in the whitelist. */
extern bool m_is_wl_changed;                                             /**< Indicates if the whitelist has been changed since last time it has been updated in the Peer Manager. */
extern pm_peer_id_t m_whitelist_peers[BLE_GAP_WHITELIST_ADDR_MAX_COUNT]; /**< List of peers currently in the whitelist. */

extern  ble_bas_t  m_bas;                                                                          /**< Structure used to identify the battery service. */
extern bool       m_in_boot_mode;                                                         /**< Current protocol mode. */
extern uint16_t   m_conn_handle;                                       /**< Handle of the current connection. */

extern sensorsim_cfg_t   m_battery_sim_cfg;                                                       /**< Battery Level sensor simulator configuration. */
extern sensorsim_state_t m_battery_sim_state;                                                     /**< Battery Level sensor simulator state. */

APP_TIMER_DEF(m_battery_timer_id);                                                                /**< Battery timer. */

extern pm_peer_id_t m_peer_id;                                                                    /**< Device reference handle to the current bonded central. */

extern ble_uuid_t m_adv_uuids[]; /**< Universally unique service identifiers. */

extern pm_peer_id_t   m_whitelist_peers[BLE_GAP_WHITELIST_ADDR_MAX_COUNT];  /**< List of peers currently in the whitelist. */
extern uint32_t       m_whitelist_peer_cnt;                                 /**< Number of peers currently in the whitelist. */
extern bool           m_is_wl_changed;                                      /**< Indicates if the whitelist has been changed since last time it has been updated in the Peer Manager. */

extern ble_advertising_t* extern_m_advertising;
extern ble_gap_sec_params_t sec_param;

extern nrf_ble_qwr_t* extern_m_qwr;
void gatt_init(void);
void conn_params_init(void);
void services_init(void);
void gap_params_init(void);
void bas_init(void);
void dis_init(void);
void hids_init(void);
void delete_bonds(void);

void sensor_simulator_init(void);
void timers_start(void);


void peer_manager_init(void);
void advertising_init(void);
void mouse_movement_send(int16_t x_delta, int16_t y_delta);
void mouse_button_send(uint8_t button);
void timers_init(void);
void advertising_start(bool erase_bonds);
void sleep_mode_enter(void);
void whitelist_set(pm_peer_id_list_skip_t skip);
void identities_set(pm_peer_id_list_skip_t skip);
extern void peripheral_enable(void);
extern void peripheral_disable(void);


void pm_evt_handler(pm_evt_t const *p_evt);
void on_hids_evt(ble_hids_t * p_hids, ble_hids_evt_t * p_evt);
void on_adv_evt(ble_adv_evt_t ble_adv_evt);
void on_ble_evt(ble_evt_t const * p_ble_evt, void * p_context);
void ble_evt_dispatch(const ble_evt_t *p_ble_evt, void*context);

void service_error_handler(uint32_t nrf_error);
void conn_params_error_handler(uint32_t nrf_error);
void ble_advertising_error_handler(uint32_t nrf_error);
#ifdef __cplusplus
}
#endif

#endif
