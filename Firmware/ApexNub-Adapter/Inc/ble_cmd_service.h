#ifndef BLE_CMD_SERVICE_H
#define BLE_CMD_SERVICE_H

#include "ble_config.h"

 
#define CMD_FRAME_SIZE 16
 

// Custom Service UUIDs (replace with your own)
#define CUSTOM_CONFIG_SERVICE_UUID 0xABCF


 
#define CMD_RX_CHAR_UUID 0xABD6
 



#define BLE_CUSTOM_USER_CONFIG_OBSERVER_PRIO 3
#include "ble_conn_state.h"
#include "nrf_sdh.h"
#include "nrf_sdh_ble.h"
#include "nrf_fstorage_sd.h"
#include "ble.h"
#include "ble_srv_common.h"



typedef struct
{


	uint8_t cmd_rx_frame[CMD_FRAME_SIZE];
	
} custom_config_t;

// Service structure
typedef struct
{
		uint16_t service_handle;

		ble_gatts_char_handles_t cmd_rx_handles;

	

	
    custom_config_t current_config;
} ble_custom_config_t;
extern ble_custom_config_t custom_config_service;
extern custom_config_t* sys_config;
extern bool  m_fds_writing;
void storage_init(void);
void ble_user_config_init(void);
void user_config_load(void);
void config_save(void);
void config_save_scheduled(void *p_event_data, uint16_t event_size);
void ble_user_config_on_ble_evt(const ble_evt_t *p_ble_evt,void*context) ;


// Helper macro for adding characteristics
#define ADD_CONFIG_CHARACTERISTIC(uuid, value_ptr, size, p_handle)              \
    BLE_UUID_BLE_ASSIGN(char_uuid, uuid);                                       \
    memset(&attr_char_value, 0, sizeof(attr_char_value));                       \
    attr_char_value.p_uuid = &char_uuid;                                        \
    attr_char_value.p_attr_md = &attr_md;                                       \
    attr_char_value.init_len = size;                                            \
    attr_char_value.max_len = size;                                             \
    attr_char_value.p_value = (uint8_t *)value_ptr;                             \
    err_code = sd_ble_gatts_characteristic_add(p_custom_config->service_handle, \
                                               &char_md,                        \
                                               &attr_char_value,                \
                                               &p_handle);                      \
		APP_ERROR_CHECK(err_code);																										\
																							 
#define SAVE_CONFIG_MACRO(uuid,value_ptr,new_value_ptr,size_t)	\
				case uuid: \
					NRF_LOG_INFO("#uuid" ##" WRITE\r\n");	\
					memcpy(value_ptr, new_value_ptr, size_t); \
					saveNeeded = true; \
					break; \


#endif
				