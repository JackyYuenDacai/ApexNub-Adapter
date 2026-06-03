#include "rtc_config.h"

static nrf_drv_rtc_t const m_rtc = NRF_DRV_RTC_INSTANCE(2);
extern ble_custom_config_t custom_config_service;
void lfclk_config(void)
{
    uint32_t err_code;

    err_code = nrf_drv_clock_init();
    APP_ERROR_CHECK(err_code);

    nrf_drv_clock_lfclk_request(NULL);
}
// RTC tick events generation.
static void rtc_handler(nrf_drv_rtc_int_type_t int_type)
{
    if (int_type == NRF_DRV_RTC_INT_TICK)
    {
        // On each RTC tick (their frequency is set in "nrf_drv_config.h")
        // we read data from our sensors.
        NRF_LOG_INFO("t!\t");
        // DARM_sensor_pour(); // Moved to report_timer.c
        // custom_config_service.current_config.gyro_x =  lis3dh_pdata.fx;//lis3dh_pdata.fx), NRF_LOG_FLOAT(lis3dh_pdata.fy), NRF_LOG_FLOAT(lis3dh_pdata.fz));
        // custom_config_service.current_config.gyro_y =  lis3dh_pdata.fy;
        // custom_config_service.current_config.gyro_z =  lis3dh_pdata.fz;
    }
}
void rtc_config(void)
{
    uint32_t err_code;

    // Initialize RTC instance with default configuration.
    nrf_drv_rtc_config_t config = NRF_DRV_RTC_DEFAULT_CONFIG;
    config.prescaler = RTC_FREQ_TO_PRESCALER(5); // Set RTC frequency to 32Hz
    err_code = nrf_drv_rtc_init(&m_rtc, &config, rtc_handler);
    APP_ERROR_CHECK(err_code);

    // Enable tick event and interrupt.
    nrf_drv_rtc_tick_enable(&m_rtc, true);

    // Power on RTC instance.
    nrf_drv_rtc_enable(&m_rtc);
}