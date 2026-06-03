#include "ble_cmd_service.h"
#include "usbd_config.h"

ble_custom_config_t custom_config_service;

 
static uint8_t cmd_rx_buffer[CMD_FRAME_SIZE] = {0};
 
static uint8_t usb_keyboard_report[9] = {0};
static uint8_t usb_mouse_report[5] = {0};
custom_config_t* sys_config = &custom_config_service.current_config;
const custom_config_t DEFAULT_CONFIG = {

    .cmd_rx_frame = {0} // Initialize macro_script array with zeros
};

uint32_t custom_config_service_init(ble_custom_config_t *p_custom_config, const custom_config_t *p_init_config)
{
    ble_uuid_t service_uuid;
    ble_uuid_t char_uuid;
    ble_gatts_char_md_t char_md;
    ble_gatts_attr_t attr_char_value;
    ble_gatts_attr_md_t attr_md;
    uint32_t err_code;

    // Initialize service structure
    memcpy(&p_custom_config->current_config, p_init_config, sizeof(custom_config_t));

    // Add custom configuration service
    BLE_UUID_BLE_ASSIGN(service_uuid, CUSTOM_CONFIG_SERVICE_UUID);
    err_code = sd_ble_gatts_service_add(BLE_GATTS_SRVC_TYPE_PRIMARY,
                                        &service_uuid,
                                        &p_custom_config->service_handle);
    VERIFY_SUCCESS(err_code);

    // Common characteristic metadata
    memset(&char_md, 0, sizeof(char_md));
    char_md.char_props.read = 1;
        char_md.char_props.write = 0;
        char_md.char_props.write_wo_resp = 1;
    char_md.p_char_user_desc = NULL;
    char_md.p_char_pf = NULL;
    char_md.p_user_desc_md = NULL;
    char_md.p_cccd_md = NULL;
    char_md.p_sccd_md = NULL;

    // Common attribute metadata
    memset(&attr_md, 0, sizeof(attr_md));
    BLE_GAP_CONN_SEC_MODE_SET_OPEN(&attr_md.read_perm);
    BLE_GAP_CONN_SEC_MODE_SET_OPEN(&attr_md.write_perm);
    attr_md.vloc = BLE_GATTS_VLOC_USER; // Store in user memory
    attr_md.rd_auth = 0;
    attr_md.wr_auth = 0;
    attr_md.vlen = 0;

    VERIFY_SUCCESS(err_code);


    ADD_CONFIG_CHARACTERISTIC(CMD_RX_CHAR_UUID,
                              &(cmd_rx_buffer),
                              sizeof(uint8_t) * CMD_FRAME_SIZE, p_custom_config->cmd_rx_handles);



#undef ADD_CONFIG_CHARACTERISTIC

    return NRF_SUCCESS;
}
void ble_user_config_init()
{


    custom_config_service_init(&custom_config_service, &custom_config_service.current_config);
}
bool  m_fds_initialized = false;
bool  m_fds_writing = false;
static void fds_evt_handler(fds_evt_t const *p_evt)
{
    switch (p_evt->id)
    {
        
    case FDS_EVT_INIT:
       
        m_fds_initialized = true;
        APP_ERROR_CHECK(p_evt->result);
        break;

    case FDS_EVT_WRITE:
       
        break;

    case FDS_EVT_DEL_RECORD:
        // Handle record deletion if needed
        break;
    default:
        break;
    }
}
fds_stat_t fds_stat_data;
void storage_init(void)
{
    ret_code_t err_code = fds_register(fds_evt_handler);
    APP_ERROR_CHECK(err_code);

    err_code = fds_init();
    APP_ERROR_CHECK(err_code);
		fds_gc();
	fds_stat(&fds_stat_data);                                                                                                                           

	;
    while (!m_fds_initialized)
    {
        app_sched_execute();
		if (NRF_LOG_PROCESS() == false)
		{
			nrf_pwr_mgmt_run();
		}
    }

}
 

static void ble_cmd_received(uint8_t cmd,uint8_t* data){
	bsp_board_led_on(1);
	switch(cmd){
		case 0xBB:
            usb_keyboard_report[0] = 0x01;
            memcpy(&usb_keyboard_report[1], data, 8);
            usbd_send_report(usb_keyboard_report, sizeof(usb_keyboard_report));
			break;
        case 0xAA:
            usb_mouse_report[0] = 0x02;
            memcpy(usb_mouse_report+1, data+1, 4);
            usbd_send_report(usb_mouse_report, sizeof(usb_mouse_report));
			break;
		default:
			break;
	}
}

void ble_user_config_on_ble_evt(const ble_evt_t *p_ble_evt,void*context)
{
 
    if (p_ble_evt->header.evt_id == BLE_GATTS_EVT_WRITE)
    {
        const ble_gatts_evt_write_t *p_evt_write = &p_ble_evt->evt.gatts_evt.params.write;
        switch (p_evt_write->uuid.uuid)
        {
		 case CMD_RX_CHAR_UUID: //16 bytes
			 NRF_LOG_DEBUG("Recv cmd: %X, Len:%d" ,((uint8_t *)p_evt_write->data)[0],((uint8_t *)p_evt_write->data)[1]);
            //((uint8_t *)p_evt_write->data)[0];
			ble_cmd_received(((uint8_t *)p_evt_write->data)[0], ((uint8_t *)p_evt_write->data) + 1);
            break;
			default:
				break;
        }
    }
 
}
NRF_SDH_BLE_OBSERVER(m_custom_config_observer,BLE_CUSTOM_USER_CONFIG_OBSERVER_PRIO, ble_user_config_on_ble_evt,&custom_config_service.service_handle);
