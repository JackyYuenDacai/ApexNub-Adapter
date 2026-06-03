#include "report_timer.h"
 

extern ble_custom_config_t custom_config_service;
uint32_t hid_report_time_ticks;
uint32_t gyro_pour_time_ticks;
extern int joy_x;
extern int joy_y;
extern uint8_t mhid_buttons;
extern uint8_t mhid_mpbuttons;
const nrf_drv_timer_t hid_report_timer = NRF_DRV_TIMER_INSTANCE(1);

uint8_t is_able_to_send_report = 0;

bool isInStasis = false;
uint32_t stasisCounter = 0;

bool is_sleep_entered = false;

uint8_t cmp_latch1[64]={0xFF};
uint8_t cmp_latch2[64]={0xFF};
bool is_report_changed(uint8_t* latch_buf,uint8_t* cmp,uint8_t size){
	
	for(int i=0;i<size;i++){
		if(latch_buf[i] != cmp[i]){
			memcpy(latch_buf,cmp,size);
			return true;
		}
	}
	return false;
	
}

static void sleep_mode_enter_handler(void *p_event_data, uint16_t event_size){

	NRF_LOG_INFO("ENTER SLEEP MODE!");
	NRF_LOG_FLUSH();
	sleep_mode_enter();
}

static void hid_report_handler()
{

	ret_code_t err_code;
	
	 
 
}
static void hid_report_timer_handler(nrf_timer_event_t event_type, void *p_context)
{
	if (event_type == NRF_TIMER_EVENT_COMPARE0){
		 
		hid_report_handler();
	}
}
void hid_report_tick_init(void)
{
	ret_code_t err_code;
	nrf_drv_timer_config_t timer_cfg = NRF_DRV_TIMER_DEFAULT_CONFIG;
	err_code = nrf_drv_timer_init(&hid_report_timer, &timer_cfg, hid_report_timer_handler);
	APP_ERROR_CHECK(err_code);
	// Setup timer for sample rate
	uint32_t time_ticks = 16000UL * 10;
	nrf_drv_timer_extended_compare(
		&hid_report_timer,
		NRF_TIMER_CC_CHANNEL0,
		time_ticks,
		NRF_TIMER_SHORT_COMPARE0_CLEAR_MASK,
		true);
}
void hid_report_tick_enable(void)
{
	nrf_drv_timer_enable(&hid_report_timer);
}
void hid_report_tick_disable(void)
{
	nrf_drv_timer_disable(&hid_report_timer);
}
