#include "ble_config.h"

/**@brief Function for handling advertising events.
 *
 * @details This function will be called for advertising events which are passed to the application.
 *
 * @param[in] ble_adv_evt  Advertising event.
 */
void on_adv_evt(ble_adv_evt_t ble_adv_evt)
{
    uint32_t err_code;

    switch (ble_adv_evt)
    {
    case BLE_ADV_EVT_DIRECTED:
        NRF_LOG_INFO("BLE_ADV_EVT_DIRECTED\r\n");
        err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING_DIRECTED);
        APP_ERROR_CHECK(err_code);
        break;

    case BLE_ADV_EVT_FAST:

        NRF_LOG_INFO("BLE_ADV_EVT_FAST\r\n");
        err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING);
        APP_ERROR_CHECK(err_code);
        break;

    case BLE_ADV_EVT_SLOW:

        NRF_LOG_INFO("BLE_ADV_EVT_SLOW\r\n");
        err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING_SLOW);
        APP_ERROR_CHECK(err_code);
        break;

    case BLE_ADV_EVT_FAST_WHITELIST:

        NRF_LOG_INFO("BLE_ADV_EVT_FAST_WHITELIST\r\n");
        err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING_WHITELIST);
        APP_ERROR_CHECK(err_code);
        break;

    case BLE_ADV_EVT_SLOW_WHITELIST:
        
        NRF_LOG_INFO("BLE_ADV_EVT_SLOW_WHITELIST\r\n");
        err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING_WHITELIST);
        APP_ERROR_CHECK(err_code);
        err_code = ble_advertising_restart_without_whitelist(extern_m_advertising);
        APP_ERROR_CHECK(err_code);
        break;

    case BLE_ADV_EVT_IDLE:
        err_code = bsp_indication_set(BSP_INDICATE_IDLE);
        APP_ERROR_CHECK(err_code);
        sleep_mode_enter();
        break;

    case BLE_ADV_EVT_WHITELIST_REQUEST:
        {
            ble_gap_addr_t whitelist_addrs[BLE_GAP_WHITELIST_ADDR_MAX_COUNT];
            ble_gap_irk_t  whitelist_irks[BLE_GAP_WHITELIST_ADDR_MAX_COUNT];
            uint32_t       addr_cnt = BLE_GAP_WHITELIST_ADDR_MAX_COUNT;
            uint32_t       irk_cnt  = BLE_GAP_WHITELIST_ADDR_MAX_COUNT;

            err_code = pm_whitelist_get(whitelist_addrs, &addr_cnt,
                                        whitelist_irks,  &irk_cnt);
            APP_ERROR_CHECK(err_code);
            NRF_LOG_DEBUG("pm_whitelist_get returns %d addr in whitelist and %d irk whitelist",
                           addr_cnt,
                           irk_cnt);

            // Set the correct identities list (no excluding peers with no Central Address Resolution).
            identities_set(PM_PEER_ID_LIST_SKIP_NO_IRK);

            // Apply the whitelist.
            err_code = ble_advertising_whitelist_reply(extern_m_advertising,
                                                       whitelist_addrs,
                                                       addr_cnt,
                                                       whitelist_irks,
                                                       irk_cnt);
            APP_ERROR_CHECK(err_code);
        }
        break;
    break;

    case BLE_ADV_EVT_PEER_ADDR_REQUEST:
        {
            pm_peer_data_bonding_t peer_bonding_data;

            // Only Give peer address if we have a handle to the bonded peer.
            if (m_peer_id != PM_PEER_ID_INVALID)
            {

                err_code = pm_peer_data_bonding_load(m_peer_id, &peer_bonding_data);
                if (err_code != NRF_ERROR_NOT_FOUND)
                {
                    APP_ERROR_CHECK(err_code);

                    // Manipulate identities to exclude peers with no Central Address Resolution.
                    identities_set(PM_PEER_ID_LIST_SKIP_ALL);

                    ble_gap_addr_t * p_peer_addr = &(peer_bonding_data.peer_ble_id.id_addr_info);
                    err_code = ble_advertising_peer_addr_reply(extern_m_advertising, p_peer_addr);
                    APP_ERROR_CHECK(err_code);
                }

            }
            break;
        }

    default:
        break;
    }
}
/**@brief Function for handling the Application's BLE Stack events.
 *
 * @param[in]   p_ble_evt   Bluetooth stack event.
 */
char oled_display_passkey_line1[5] = "PIN ";
char oled_display_passkey_line2[5] = "";
char oled_display_passkey_line3[5] = "";
static ble_gap_sec_params_t sec_params_auth;
void on_ble_evt(ble_evt_t const *p_ble_evt, void *p_context)
{

    uint32_t err_code;
    int8_t rssi;
	//NRF_LOG_INFO("ON_BLE:%02X",p_ble_evt->header.evt_id);
    switch (p_ble_evt->header.evt_id)
    {
    case BLE_GAP_EVT_PASSKEY_DISPLAY:
        NRF_LOG_INFO("PASSKEY:%s", (uint32_t)(p_ble_evt->evt.gap_evt.params.passkey_display.passkey));

        for (int i = 0; i < 4; i++)
        {
            oled_display_passkey_line2[i] = (p_ble_evt->evt.gap_evt.params.passkey_display.passkey)[i];
        }
        oled_display_passkey_line3[0] = ' ';
        oled_display_passkey_line3[1] = (p_ble_evt->evt.gap_evt.params.passkey_display.passkey)[4];
        oled_display_passkey_line3[2] = (p_ble_evt->evt.gap_evt.params.passkey_display.passkey)[5];
        oled_display_passkey_line3[3] = ' ';
		 

		
        
        break;
		
    case BLE_GAP_EVT_AUTH_STATUS:
    {
        NRF_LOG_INFO("Auth Status:\n");
        uint8_t status = p_ble_evt->evt.gap_evt.params.auth_status.auth_status;
        if (status == BLE_GAP_SEC_STATUS_SUCCESS)
        {
            NRF_LOG_INFO("Encryption success");
        }
        else
        {
            NRF_LOG_ERROR("Encryption failed: 0x%02X", status);

            // ????????
            ble_gap_sec_params_t fallback_sec = {
                .bond = 1,
                .mitm = 0,
                .lesc = 0};
            sd_ble_gap_sec_params_reply(m_conn_handle,
                                        BLE_GAP_SEC_STATUS_SUCCESS,
                                        &fallback_sec,
                                        NULL);
        }
        break;
    }
    case BLE_GAP_EVT_SEC_REQUEST:
    {
        static ble_gap_sec_params_t sec_params_reply = {
            .bond = SEC_PARAM_BOND,
            .mitm = SEC_PARAM_MITM,
            .lesc = SEC_PARAM_LESC, // API v2 ????
            .io_caps = SEC_PARAM_IO_CAPABILITIES};

        sd_ble_gap_sec_params_reply(m_conn_handle,
                                    BLE_GAP_SEC_STATUS_SUCCESS,
                                    &sec_params_reply,
                                    NULL);
        break;
    }
    case BLE_GAP_EVT_SEC_INFO_REQUEST:
    {
        NRF_LOG_INFO("Security Info Requested.\n");
        pm_peer_data_bonding_t peer_data;
        if (pm_peer_data_bonding_load(m_peer_id, &peer_data) == NRF_SUCCESS)
        {
            ble_gap_enc_info_t enc_info = {
                .ltk = {0},
                .auth = 1,
                .ltk_len = 16};
            memcpy(enc_info.ltk, peer_data.own_ltk.enc_info.ltk, 16);

            sd_ble_gap_sec_info_reply(p_ble_evt->evt.gap_evt.conn_handle,
                                      &enc_info,
                                      NULL,
                                      NULL);
        }
        else
        {
            // ??????
            NRF_LOG_WARNING("No LTK, initiating re-pairing");

            sd_ble_gap_authenticate(m_conn_handle, &sec_param);
        }
        break;
    }
 
    case BLE_GAP_EVT_CONNECTED:
            NRF_LOG_INFO("Connected");
			//update_advertising_data_with_nus();
            err_code = bsp_indication_set(BSP_INDICATE_CONNECTED);
            APP_ERROR_CHECK(err_code);
            m_conn_handle = p_ble_evt->evt.gap_evt.conn_handle;
            err_code = nrf_ble_qwr_conn_handle_assign(extern_m_qwr, m_conn_handle);
            APP_ERROR_CHECK(err_code);
            break;


    case BLE_GAP_EVT_DISCONNECTED:

        NRF_LOG_INFO("Disconnect reason: 0x%X\n\r",
                     p_ble_evt->evt.gap_evt.params.disconnected.reason);
        err_code = bsp_indication_set(BSP_INDICATE_IDLE);
        APP_ERROR_CHECK(err_code);

        m_conn_handle = BLE_CONN_HANDLE_INVALID;

 
        is_able_to_send_report = 0;
        break; // BLE_GAP_EVT_DISCONNECTED
    case BLE_GAP_EVT_PHY_UPDATE_REQUEST:
        {
            NRF_LOG_DEBUG("PHY update request.");
            ble_gap_phys_t const phys =
            {
                .rx_phys = BLE_GAP_PHY_AUTO,
                .tx_phys = BLE_GAP_PHY_AUTO,
            };
            err_code = sd_ble_gap_phy_update(p_ble_evt->evt.gap_evt.conn_handle, &phys);
            APP_ERROR_CHECK(err_code);
        } break;
    case BLE_GATTC_EVT_TIMEOUT:
        // Disconnect on GATT Client timeout event.
        NRF_LOG_DEBUG("GATT Client Timeout.\r\n");
        err_code = sd_ble_gap_disconnect(p_ble_evt->evt.gattc_evt.conn_handle,
                                         BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
        APP_ERROR_CHECK(err_code);
        break; // BLE_GATTC_EVT_TIMEOUT

    case BLE_GATTS_EVT_TIMEOUT:
        // Disconnect on GATT Server timeout event.
        NRF_LOG_DEBUG("GATT Server Timeout.\r\n");
        err_code = sd_ble_gap_disconnect(p_ble_evt->evt.gatts_evt.conn_handle,
                                         BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
        APP_ERROR_CHECK(err_code);
        break; // BLE_GATTS_EVT_TIMEOUT

    default:
        // No implementation needed.
        break;
    }
}
/**@brief Function for handling Peer Manager events.
 *
 * @param[in] p_evt  Peer Manager event.
 */
void pm_evt_handler(pm_evt_t const *p_evt)
{
    pm_handler_on_pm_evt(p_evt);
    pm_handler_disconnect_on_sec_failure(p_evt);
    pm_handler_flash_clean(p_evt);
    ret_code_t err_code;

    switch (p_evt->evt_id)
    {
    case PM_EVT_BONDED_PEER_CONNECTED:
    {
        NRF_LOG_INFO("Connected to a previously bonded device.\r\n");
    }
    break;

    case PM_EVT_CONN_SEC_SUCCEEDED:
    {

        NRF_LOG_INFO("Connection secured. Role: %d. conn_handle: %d, Procedure: %d\r\n",
                     ble_conn_state_role(p_evt->conn_handle),
                     p_evt->conn_handle,
                     p_evt->params.conn_sec_succeeded.procedure);
        // oled_anim_config
 
 
        m_peer_id = p_evt->peer_id;

        // Note: You should check on what kind of white list policy your application should use.
        if (p_evt->params.peer_data_update_succeeded.flash_changed && (p_evt->params.peer_data_update_succeeded.data_id == PM_PEER_DATA_ID_BONDING))
        {
            NRF_LOG_INFO("New Bond, add the peer to the whitelist if possible\r\n");
            NRF_LOG_INFO("\tm_whitelist_peer_cnt %d, MAX_PEERS_WLIST %d\r\n",
                         m_whitelist_peer_cnt + 1,
                         BLE_GAP_WHITELIST_ADDR_MAX_COUNT);

            if (m_whitelist_peer_cnt < BLE_GAP_WHITELIST_ADDR_MAX_COUNT)
            {
                // Bonded to a new peer, add it to the whitelist.
                m_whitelist_peers[m_whitelist_peer_cnt++] = m_peer_id;
                m_is_wl_changed = true;
            }
        }
		
        is_able_to_send_report = 1;
    }
    break;
        case PM_EVT_PEERS_DELETE_SUCCEEDED:
            advertising_start(false);
            break;
        case PM_EVT_PEER_DATA_UPDATE_SUCCEEDED:
            if (     p_evt->params.peer_data_update_succeeded.flash_changed
                 && (p_evt->params.peer_data_update_succeeded.data_id == PM_PEER_DATA_ID_BONDING))
            {
                NRF_LOG_INFO("New Bond, add the peer to the whitelist if possible");
                // Note: You should check on what kind of white list policy your application should use.

                whitelist_set(PM_PEER_ID_LIST_SKIP_NO_ID_ADDR);
            }
            break;

        default:
            break;
    }
}

/**@brief Function for handling Service errors.
 *
 * @details A pointer to this function will be passed to each service which may need to inform the
 *          application about an error.
 *
 * @param[in]   nrf_error   Error code containing information about what went wrong.
 */
void service_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}

/**@brief Function for handling advertising errors.
 *
 * @param[in] nrf_error  Error code containing information about what went wrong.
 */
void ble_advertising_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}