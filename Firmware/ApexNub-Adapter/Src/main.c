

#include <stdint.h>
#include <string.h>

/*
NRF51822 Adjust
ROM start to 0x0001B000
RAM start to 0x20001fe8 Size 0x2018
Using SD S130
-DAPEXNUB_B22
NRF52832 Adjust
ROM start to 0x0001f000 Size 0x61000
RAM start to 0x20002128 Size 0xDED8
Using SD S132
-DAPEXNUB_B22
*/

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

#define DEBUG 1

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"

// #define NRF_LOG_MODULE_NAME "APEXNUB"

#include "nrf_drv_ppi.h"
#include "nrf_drv_timer.h"
#include "nrf_temp.h"
#include "nrf_drv_clock.h"
#include "nrf_drv_rtc.h"
#include "nrf_drv_twi.h"
#include "nrf_crypto.h"
#include "mem_manager.h"

#include "ble_config.h"
#include "rtc_config.h"
#include "report_timer.h"

#include "usbd_config.h"

#include "nrf_delay.h"

static bool m_in_boot_mode = false;                      /**< Current protocol mode. */
static uint16_t m_conn_handle = BLE_CONN_HANDLE_INVALID; /**< Handle of the current connection. */
static sensorsim_cfg_t m_battery_sim_cfg;                /**< Battery Level sensor simulator configuration. */
static sensorsim_state_t m_battery_sim_state;            /**< Battery Level sensor simulator state. */
static bool m_caps_on = false;                           /**< Variable to indicate if Caps Lock is turned on. */
static pm_peer_id_t m_peer_id;                           /**< Device reference handle to the current bonded central. */

static ble_uuid_t m_adv_uuids[] = {{BLE_UUID_HUMAN_INTERFACE_DEVICE_SERVICE, BLE_UUID_TYPE_BLE}};
static void sys_evt_dispatch(uint32_t sys_evt)
{
    // Dispatch the system event to the fstorage module, where it will be
    // dispatched to the Flash Data Storage (FDS) module.
    // fs_sys_event_handler(sys_evt);

    // Dispatch to the Advertising module last, since it will check if there are any
    // pending flash operations in fstorage. Let fstorage process system events first,
    // so that it can report correctly to the Advertising module.
    // ble_advertising_on_sys_evt(sys_evt);
}
void assert_nrf_callback(uint16_t line_num, const uint8_t *p_file_name)
{
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

static void scheduler_init(void)
{
    APP_SCHED_INIT(SCHED_MAX_EVENT_DATA_SIZE, SCHED_QUEUE_SIZE);
}

static void ble_stack_init(void)
{
    ret_code_t err_code;

    err_code = nrf_sdh_enable_request();
    APP_ERROR_CHECK(err_code);

    // Configure the BLE stack using the default settings.
    // Fetch the start address of the application RAM.
    uint32_t ram_start = 0;
    err_code = nrf_sdh_ble_default_cfg_set(APP_BLE_CONN_CFG_TAG, &ram_start);
    APP_ERROR_CHECK(err_code);

    // Enable BLE stack.
    err_code = nrf_sdh_ble_enable(&ram_start);
    APP_ERROR_CHECK(err_code);

    // Register a handler for BLE events.
    NRF_SDH_BLE_OBSERVER(m_ble_observer, APP_BLE_OBSERVER_PRIO, on_ble_evt, NULL);
}
static void power_manage(void)
{
    app_sched_execute();
    if (NRF_LOG_PROCESS() == false)
    {
        nrf_pwr_mgmt_run();
    }
}
static void bsp_event_handler(bsp_event_t event)
{
    uint32_t err_code;
    static uint8_t motion_state = 0;
    NRF_LOG_INFO("EVENT:%d\n", event);
    switch (event)
    {
    default:
        break;
    }
}
/**@brief Function for initializing buttons and leds.
 *
 * @param[out] p_erase_bonds  Will be true if the clear bonding button was pressed to wake the application up.
 */
void power_init()
{

    NRF_POWER->DCDCEN = 1;
    *((volatile uint32_t *)0x40000500) = 0x00000003;
    *((volatile uint32_t *)0x40000600) = 0x00000001;
}
void h1_radio_wakeup(void)
{
    NRF_RADIO->POWER = 0;
    *((volatile uint32_t *)0x40001774) = 0x00000001;
    NRF_RADIO->POWER = 1;
    *((volatile uint32_t *)0x40001774) = 0x00000000;

    NRF_RADIO->TASKS_DISABLE = 1;
    while (NRF_RADIO->EVENTS_DISABLED == 0)
        ;
    NRF_RADIO->EVENTS_DISABLED = 0;

    NRF_RADIO->TASKS_RXEN = 1;
    NRF_RADIO->TASKS_DISABLE = 1;
}
void peripheral_enable()
{

    hid_report_tick_enable();
}
void peripheral_disable()
{

    hid_report_tick_disable();
}
static void buttons_leds_init(bool *p_erase_bonds)
{
    ret_code_t err_code;
    bsp_event_t startup_event;

    err_code = bsp_init(BSP_INIT_LEDS | BSP_INIT_BUTTONS, bsp_event_handler);
    APP_ERROR_CHECK(err_code);

    err_code = bsp_btn_ble_init(NULL, &startup_event);
    APP_ERROR_CHECK(err_code);

    *p_erase_bonds = (startup_event == BSP_EVENT_CLEAR_BONDING_DATA);
}

/**@brief Function for initializing the nrf log module.
 */
static void log_init(void)
{
    ret_code_t err_code = NRF_LOG_INIT(NULL);
    APP_ERROR_CHECK(err_code);

    NRF_LOG_DEFAULT_BACKENDS_INIT();
}

/**@brief Function for initializing power management.
 */
static void power_management_init(void)
{
    ret_code_t err_code;
    err_code = nrf_pwr_mgmt_init();
    APP_ERROR_CHECK(err_code);
}

/**@brief Function for handling the idle state (main loop).
 *
 * @details If there is no pending log operation, then sleep until next the next event occurs.
 */
static void idle_state_handle(void)
{
    app_sched_execute();
    if (NRF_LOG_PROCESS() == false)
    {
        nrf_pwr_mgmt_run();
    }
}

static void lfclk_config(void)
{
    ret_code_t err_code = nrf_drv_clock_init();
    APP_ERROR_CHECK(err_code);

    nrf_drv_clock_lfclk_request(NULL);
}
/**@brief Function for application main entry.
 */
extern uint8_t m_report_queue_count;
int main(void)
{
    bool erase_bonds;
    uint32_t err_code;
    uint32_t reset_reas;

    log_init();

    reset_reas = NRF_POWER->RESETREAS;
    NRF_LOG_INFO("Reset reason: 0x%08x", reset_reas);
    NRF_POWER->RESETREAS = reset_reas;

    nrf_temp_init();
    lfclk_config();

    timers_init();
    nrf_delay_ms(100);

    buttons_leds_init(&erase_bonds);

    err_code = nrf_mem_init();
    APP_ERROR_CHECK(err_code);
 
    power_management_init();

    ble_stack_init();

    scheduler_init();

    // storage_init();
    /*nrf_drv_rng_config_t config = NRF_DRV_RNG_DEFAULT_CONFIG;
    err_code = nrf_drv_rng_init(&config);
    if(err_code != NRF_ERROR_MODULE_ALREADY_INITIALIZED)
        APP_ERROR_CHECK(err_code);*/

    gap_params_init();
    gatt_init();
    advertising_init();

    services_init();


    conn_params_init();
    peer_manager_init();
    if (erase_bonds == true)
    {
        NRF_LOG_INFO("Bonds erased!.");
    }
    // Enter main loop.
    // Start execution.
    NRF_LOG_INFO("HID Mouse Start!.");
    usbd_config();
 
    hid_report_tick_init();

    advertising_start(true);


    peripheral_enable();

    for (;;)
    {
		if(m_report_queue_count <= 0){
			bsp_board_led_off(1);
		} 
		while (app_usbd_event_queue_process());
        app_sched_execute();

        if (!NRF_LOG_PROCESS())
        {
            nrf_pwr_mgmt_run();
        }
    }
}

/**
 * @}
 */
