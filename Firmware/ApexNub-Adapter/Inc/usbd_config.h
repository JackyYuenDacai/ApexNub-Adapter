#ifndef USBD_CONFIG_H
#define USBD_CONFIG_H
#include "app_usbd.h"
#include "app_usbd_core.h"
#include "app_usbd_hid_generic.h"

extern bool m_report_pending;
#ifndef USBD_POWER_DETECTION
#define USBD_POWER_DETECTION false
#endif

#define LED_USB_START    (BSP_BOARD_LED_0)
#define LED_HID_REP_IN   (BSP_BOARD_LED_1)
/**
 * @brief HID generic class interface number.
 * */
#define HID_GENERIC_INTERFACE  0

/**
 * @brief HID generic class endpoint number.
 * */
#define HID_GENERIC_EPIN       NRF_DRV_USBD_EPIN1
/**
 * @brief Number of reports defined in report descriptor.
 */
#define REPORT_IN_QUEUE_SIZE    2

/**
 * @brief Size of maximum output report. HID generic class will reserve
 *        this buffer size + 1 memory space. 
 *
 * Maximum value of this define is 63 bytes. Library automatically adds
 * one byte for report ID. This means that output report size is limited
 * to 64 bytes.
 */
#define REPORT_OUT_MAXSIZE  0

/**
 * @brief Feature report maximum size. HID generic class will reserve
 *        this buffer size + 1 memory space. 
 */
#define REPORT_FEATURE_MAXSIZE  31

/**
 * @brief HID generic class endpoints count.
 * */
#define HID_GENERIC_EP_COUNT  1

/**
 * @brief List of HID generic class endpoints.
 * */
#define ENDPOINT_LIST()                                      \
(                                                            \
        HID_GENERIC_EPIN                                     \
)

void hid_user_ev_handler(app_usbd_class_inst_t const * p_inst,
                                app_usbd_hid_user_event_t event);
void hid_user_ev_handler(app_usbd_class_inst_t const * p_inst,
                                app_usbd_hid_user_event_t event);
void usbd_user_ev_handler(app_usbd_event_type_t event);
void usbd_config(void);
void usbd_send_report(uint8_t* data,int size);
#endif
