#include "usbd_config.h"
#include "nrf_log.h"
#include "bsp.h"
#include <string.h>

#define USBD_REPORT_QUEUE_CAPACITY 8
#define USBD_REPORT_MAX_SIZE       16

typedef struct
{
    uint8_t data[USBD_REPORT_MAX_SIZE];
    uint8_t size;
} usbd_report_queue_item_t;

bool m_report_pending;
static usbd_report_queue_item_t m_report_queue[USBD_REPORT_QUEUE_CAPACITY];
static uint8_t m_report_queue_head;
static uint8_t m_report_queue_tail;
uint8_t m_report_queue_count;

static void usbd_report_try_flush_queue(void);
static void usbd_report_queue_reset(void);
	
void hid_user_ev_handler(app_usbd_class_inst_t const * p_inst,
                                app_usbd_hid_user_event_t event)
{
    switch (event)
    {
        case APP_USBD_HID_USER_EVT_OUT_REPORT_READY:
        {
            /* No output report defined for this example.*/
            ASSERT(0);
            break;
        }
        case APP_USBD_HID_USER_EVT_IN_REPORT_DONE:
        {
            m_report_pending = false;
            NRF_LOG_INFO("HID send done");
            usbd_report_try_flush_queue();
            //hid_generic_mouse_process_state();
            //bsp_board_led_invert(LED_HID_REP_IN);
            break;
        }
        case APP_USBD_HID_USER_EVT_SET_BOOT_PROTO:
        {
            UNUSED_RETURN_VALUE(hid_generic_clear_buffer(p_inst));
            NRF_LOG_INFO("SET_BOOT_PROTO");
            break;
        }
        case APP_USBD_HID_USER_EVT_SET_REPORT_PROTO:
        {
            UNUSED_RETURN_VALUE(hid_generic_clear_buffer(p_inst));
            NRF_LOG_INFO("SET_REPORT_PROTO");
            break;
        }
        default:
            break;
    }
}
APP_USBD_HID_GENERIC_SUBCLASS_REPORT_DESC(mouse_desc, \
{                \
// Keyboard
0x05, 0x01,                   
0x09, 0x06,                    // USAGE (Keyboard)
0xa1, 0x01,                    // COLLECTION (Application)
0x85, 0x01,					   // report id 1
0x05, 0x07,                    //   USAGE_PAGE (Keyboard)
0x19, 0xe0,                    //   USAGE_MINIMUM (Keyboard LeftControl)
0x29, 0xe7,                    //   USAGE_MAXIMUM (Keyboard Right GUI)
0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
0x25, 0x01,                    //   LOGICAL_MAXIMUM (1)
0x75, 0x01,                    //   REPORT_SIZE (1)
0x95, 0x08,                    //   REPORT_COUNT (8)
0x81, 0x02,                    //   INPUT (Data,Var,Abs)
0x95, 0x01,                    //   REPORT_COUNT (1)
0x75, 0x08,                    //   REPORT_SIZE (8)
0x81, 0x03,                    //   INPUT (Cnst,Var,Abs)
0x95, 0x05,                    //   REPORT_COUNT (5)
0x75, 0x01,                    //   REPORT_SIZE (1)
0x05, 0x08,                    //   USAGE_PAGE (LEDs)
0x19, 0x01,                    //   USAGE_MINIMUM (Num Lock)
0x29, 0x05,                    //   USAGE_MAXIMUM (Kana)
0x91, 0x02,                    //   OUTPUT (Data,Var,Abs)
0x95, 0x01,                    //   REPORT_COUNT (1)
0x75, 0x03,                    //   REPORT_SIZE (3)
0x91, 0x03,                    //   OUTPUT (Cnst,Var,Abs)
0x95, 0x06,                    //   REPORT_COUNT (6)
0x75, 0x08,                    //   REPORT_SIZE (8)
0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
0x25, 0x65,                    //   LOGICAL_MAXIMUM (101)
0x05, 0x07,                    //   USAGE_PAGE (Keyboard)
0x19, 0x00,                    //   USAGE_MINIMUM (Reserved (no event indicated))
0x29, 0x65,                    //   USAGE_MAXIMUM (Keyboard Application)
0x81, 0x00,                    //   INPUT (Data,Ary,Abs)
0xc0,                           // END_COLLECTION
// Mouse
0x05, 0x01,        // USAGE_PAGE (Generic Desktop)
0x09, 0x02,        // USAGE (Mouse)
0xA1, 0x01,        // COLLECTION (Application)
0x85, 0x02,        //   REPORT_ID (2)
0x09, 0x01,        //   USAGE (Pointer)
0xA1, 0x00,        //   COLLECTION (Physical)
0x05, 0x09,        //     USAGE_PAGE (Button)
0x19, 0x01,        //     USAGE_MINIMUM (Button 1)
0x29, 0x03,        //     USAGE_MAXIMUM (Button 3)
0x15, 0x00,        //     LOGICAL_MINIMUM (0)
0x25, 0x01,        //     LOGICAL_MAXIMUM (1)
0x95, 0x03,        //     REPORT_COUNT (3)
0x75, 0x01,        //     REPORT_SIZE (1)
0x81, 0x02,        //     INPUT (Data,Var,Abs)
0x95, 0x01,        //     REPORT_COUNT (1)
0x75, 0x05,        //     REPORT_SIZE (5)
0x81, 0x03,        //     INPUT (Cnst,Var,Abs)
0x05, 0x01,        //     USAGE_PAGE (Generic Desktop)
0x09, 0x30,       /*     Usage (X),                      */     \
0x09, 0x31,       /*     Usage (Y),                      */     \
0x09, 0x38,       /*     Usage (Scroll),                 */     \
0x15, 0x81,       /*     Logical Minimum (-127),         */     \
0x25, 0x7F,       /*     Logical Maximum (127),          */     \
0x75, 0x08,       /*     Report Size (8),                */     \
0x95, 0x03,       /*     Report Count (3),               */     \
0x81, 0x06,        //     INPUT (Data,Var,Rel)
0xC0,              //   END_COLLECTION
0xC0               // END_COLLECTION
}
);
static const app_usbd_hid_subclass_desc_t * reps[] = {&mouse_desc};
app_usbd_class_inst_t const * class_inst_generic;
void usbd_user_ev_handler(app_usbd_event_type_t event)
{
    switch (event)
    {
        case APP_USBD_EVT_DRV_SOF:
            break;
        case APP_USBD_EVT_DRV_RESET:
            m_report_pending = false;
            usbd_report_queue_reset();
            break;
        case APP_USBD_EVT_DRV_SUSPEND:
            m_report_pending = false;
            usbd_report_queue_reset();
            app_usbd_suspend_req(); // Allow the library to put the peripheral into sleep mode
            bsp_board_leds_off();
            break;
        case APP_USBD_EVT_DRV_RESUME:
            m_report_pending = false;
            bsp_board_led_on(LED_USB_START);
            break;
        case APP_USBD_EVT_STARTED:
            m_report_pending = false;
            usbd_report_try_flush_queue();
            bsp_board_led_on(LED_USB_START);
            break;
        case APP_USBD_EVT_STOPPED:
            app_usbd_disable();
            bsp_board_leds_off();
            break;
        case APP_USBD_EVT_POWER_DETECTED:
            NRF_LOG_INFO("USB power detected");
            if (!nrf_drv_usbd_is_enabled())
            {
                app_usbd_enable();
            }
            break;
        case APP_USBD_EVT_POWER_REMOVED:
            NRF_LOG_INFO("USB power removed");
            app_usbd_stop();
            break;
        case APP_USBD_EVT_POWER_READY:
            NRF_LOG_INFO("USB ready");
            app_usbd_start();
            break;
        default:
            break;
    }
}
APP_USBD_HID_GENERIC_GLOBAL_DEF(m_app_hid_generic,
                                HID_GENERIC_INTERFACE,
                                hid_user_ev_handler,
                                ENDPOINT_LIST(),
                                reps,
                                REPORT_IN_QUEUE_SIZE,
                                REPORT_OUT_MAXSIZE,
                                REPORT_FEATURE_MAXSIZE,
                                APP_USBD_HID_SUBCLASS_BOOT,
                                APP_USBD_HID_PROTO_MOUSE);

static void usbd_report_queue_reset(void)
{
    m_report_queue_head = 0;
    m_report_queue_tail = 0;
    m_report_queue_count = 0;
}

static bool usbd_report_queue_push(uint8_t const * data, uint8_t size)
{
    usbd_report_queue_item_t * item;

    if (size > USBD_REPORT_MAX_SIZE)
    {
        NRF_LOG_WARNING("HID queue drop: size=%d too large", size);
        return false;
    }

    if (m_report_queue_count >= USBD_REPORT_QUEUE_CAPACITY)
    {
        NRF_LOG_WARNING("HID queue full: size=%d", size);
        return false;
    }

    item = &m_report_queue[m_report_queue_tail];
    item->size = size;
    memcpy(item->data, data, size);

    m_report_queue_tail = (m_report_queue_tail + 1) % USBD_REPORT_QUEUE_CAPACITY;
    m_report_queue_count++;
    NRF_LOG_INFO("HID queued in backlog: size=%d depth=%d", size, m_report_queue_count);
    return true;
}

static ret_code_t usbd_report_try_send(uint8_t const * data, uint8_t size)
{
    ret_code_t err_code;

    err_code = app_usbd_hid_generic_in_report_set(&m_app_hid_generic, data, size);
    if (err_code == NRF_SUCCESS)
    {
        m_report_pending = true;
        NRF_LOG_INFO("HID send queued: size=%d", size);
        NRF_LOG_HEXDUMP_DEBUG(data, size);
        return NRF_SUCCESS;
    }

    NRF_LOG_WARNING("HID send failed: err=%d size=%d", err_code, size);
    return err_code;
}

static void usbd_report_try_flush_queue(void)
{
    usbd_report_queue_item_t * item;

    if (m_report_pending || (m_report_queue_count == 0))
    {
        return;
    }

    item = &m_report_queue[m_report_queue_head];
    NRF_LOG_INFO("HID flush queued report: size=%d depth=%d", item->size, m_report_queue_count);
    if (usbd_report_try_send(item->data, item->size) != NRF_SUCCESS)
    {
        return;
    }

    m_report_queue_head = (m_report_queue_head + 1) % USBD_REPORT_QUEUE_CAPACITY;
    m_report_queue_count--;
}


static ret_code_t idle_handle(app_usbd_class_inst_t const * p_inst, uint8_t report_id)
{
    switch (report_id)
    {
        case 0:
        {
            uint8_t report[] = {0xBE, 0xEF};
            return app_usbd_hid_generic_idle_report_set(
              &m_app_hid_generic,
              report,
              sizeof(report));
			
        }
        default:
            return NRF_ERROR_NOT_SUPPORTED;
    }
    
}
void usbd_send_report(uint8_t* data,int size){
    NRF_LOG_INFO("HID send request: size=%d pending=%d", size, m_report_pending);
 
    if (m_report_pending)
    {
        NRF_LOG_WARNING("HID send skipped: report pending");
        usbd_report_queue_push(data, (uint8_t)size);
        return;
    }

    if (usbd_report_try_send(data, (uint8_t)size) == NRF_SUCCESS)
    {
        return;
    }

    usbd_report_queue_push(data, (uint8_t)size);
}
void usbd_config(){
	ret_code_t ret;
	static const app_usbd_config_t usbd_config = {
        .ev_state_proc = usbd_user_ev_handler
    };
    m_report_pending = false;
	usbd_report_queue_reset();
	 
	ret = app_usbd_init(&usbd_config);
    APP_ERROR_CHECK(ret);
	    app_usbd_class_inst_t const * class_inst_generic;
    class_inst_generic = app_usbd_hid_generic_class_inst_get(&m_app_hid_generic);
    ret = hid_generic_idle_handler_set(class_inst_generic, idle_handle);
 
    APP_ERROR_CHECK(ret);
	
    ret = app_usbd_class_append(class_inst_generic);
    APP_ERROR_CHECK(ret);
	if (USBD_POWER_DETECTION)
    {
        ret = app_usbd_power_events_enable();
        APP_ERROR_CHECK(ret);
    }
    else
    {
        NRF_LOG_INFO("No USB power detection enabled\r\nStarting USB now");

        app_usbd_enable();
        app_usbd_start();
    }
}
