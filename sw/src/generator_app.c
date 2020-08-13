/**
 * @file generator_app.c
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * Radar Waveform Generator sub-app. 
 * @date 2020-08-09
 */

#include "common.h"
#include "generator_app.h"
#include "FreeRTOS.h"
#include "lwipopts.h"
#include "netif/xadapter.h"

#include "messages.pb.h"

void generator_app_thread(void *p);

extern void send_ack(xQueueHandle queue, Ack_msg_Retval retval);

/* Protobuf message for generator debug samples */
Debug_msg debug_samples_msg;

/**
 * @brief Initialize generator sub-app structure and create task
 * 
 * @param app Generator sub-app instance pointer.
 * @param first_message App creation message. Initial coniguration is received here.
 * @param net_in_queue Input protobuf message queue handle.
 * @param main_queue Main application protobuf message queue handle.
 * @param net_out_queue Output protobuf message queue handle.
 */
void generator_app_init (generator_app_t *app, Base_msg *first_message, xQueueHandle net_in_queue, xQueueHandle main_queue, xQueueHandle net_out_queue){

	*app = (generator_app_t){0};

    Waveform_Generator_t *wg = &app->wg;

    /* Init waveform generator instance */
    generator_init(wg, MY_GENERATOR_ADDRESS, DEBUG_DMA_ID); //TODO: Error handling

    /* Init debug */
    generator_enable_debug(wg);

    /* Apply first configuration */
    generator_app_decode_config(app,first_message);

    /* Init queue handles - Queues are already created in main app*/
    app->net_in_queue = net_in_queue;
    app->main_app_queue = main_queue;
    app->net_out_queue = net_out_queue;

    /* Launch task */
	sys_thread_new("generator_app", generator_app_thread,
		(void*)app,
		THREAD_STACKSIZE,
		DEFAULT_THREAD_PRIO);
}

/**
 * @brief Decodes protobuf configuration messages and applies it to generator.
 * 
 * @param app Generator sub-app instance pointer.
 * @param config_message Protobuf configuration message
 * @return int -1 on ERROR 0 on SUCCESS
 */
int generator_app_decode_config(generator_app_t *app, Base_msg *config_message){

    Generator_Config_msg *config;
    int retval = 0;

    /* Is the received message a configuration ?
    *  Is the received message a generator configuration ?
    *  */
    if (config_message->which_message == Base_msg_config_tag &&
        config_message->config.which_config == Config_msg_generator_tag){
        
        config = &(config_message->config.generator);

        /* Decode modulation */
        switch (config->which_modulation_config){
            case Generator_Config_msg_const_freq_tag:
                /* Decode continuous or pulsed */
                if (config->mode == Generator_Config_msg_Mode_CONTINUOUS)
                {
                    retval = set_continuous_mode_constant_freq(&app->wg,
                                                               config->const_freq.freq_khz);
                }
                else
                {
                    retval = set_pulsed_mode_constant_freq(&app->wg,config->period_us,
                                                  config->pulse_length_us,
                                                  config->const_freq.freq_khz);
                }
                break;
            case Generator_Config_msg_freq_mod_tag:
                /* Decode continuous or pulsed */
            	if (config->mode == Generator_Config_msg_Mode_CONTINUOUS)
					{
						retval = set_continuous_mode_freq_mod(&app->wg,
                                                     config->freq_mod.low_freq_khz,
                                                     config->freq_mod.high_freq_khz,
                                                     config->freq_mod.length_us);
					}
					else
					{
						retval = set_pulsed_mode_freq_mod(&app->wg,
                                                 config->period_us,
                                                 config->pulse_length_us,
                                                 config->freq_mod.low_freq_khz,
                                                 config->freq_mod.high_freq_khz);
					}
                break;
            case Generator_Config_msg_phase_mod_tag:
                /* Decode continuous or pulsed */
                if (config->mode == Generator_Config_msg_Mode_CONTINUOUS)
					{
						retval = set_continuous_mode_phase_mod(&app->wg,
                                                    config->phase_mod.freq_khz,
                                                    config->phase_mod.barker_seq_num,
                                                    config->phase_mod.barker_subpulse_length_us*config->phase_mod.barker_seq_num);
					}
					else
					{
						retval = set_pulsed_mode_phase_mod(&app->wg,
                                                  config->period_us,
                                                  config->pulse_length_us,
                                                  config->phase_mod.freq_khz,
                                                  config->phase_mod.barker_seq_num);
					}
                break;
        }

    }
    else{
        retval = -1;
    }
    
    return retval;
}

/**
 * @brief Decodes generator control message commands.
 * 
 * @param app Generator sub-app instance pointer.
 * @param config_message Protobuf control message.
 */
void generator_app_decode_control(generator_app_t *app, Base_msg *config_message){
    
    Control_msg *control;
    
    int valid_message = 0;
    int debug_error = 0;
    int debug_is_valid = 0;

    /* Is the received message a control message? */
    if (config_message->which_message == Base_msg_control_tag){
        control = &(config_message->control);

        switch (control->command)
        {
        case Control_msg_Command_START:
            generator_start(&app->wg);
            valid_message = 1;
            break;
        
        case Control_msg_Command_STOP:
            generator_stop(&app->wg);
            valid_message = 1;
            break;
        
        case Control_msg_Command_TRIG_DBG:
            valid_message = 1;
            /* Trigger debug samples transfer  */
            /* This gets samples form PL to PS */
            if (generator_trigger_debug(&app->wg) < 0 ){
                debug_error  = 1;
            }
            else{
                /* Successful DMA transfer */
                /* Build protobuf message  */
                generator_get_i_samples(&app->wg, debug_samples_msg.i_samples, app->wg.valid_debug_samples);
                generator_get_q_samples(&app->wg, debug_samples_msg.q_samples, app->wg.valid_debug_samples);
                debug_samples_msg.num_samples = app->wg.valid_debug_samples;
                debug_is_valid = 1;
            }
            break;
        
        default:
            valid_message = 0;
            break;
        }

        
    }
    else{
        valid_message = 0;
    }
    
    /* Check message errors */
    if (!valid_message){
        send_ack(app->net_out_queue, Ack_msg_Retval_BAD_COMMAND);
        
    }
    else{
        /* DMA debug transfer was successful. Inform that debug samples are valid */
        if(debug_is_valid){
            send_ack(app->net_out_queue, Ack_msg_Retval_DEBUG_IS_VALID);
        }
        else if (debug_error)
        {
            send_ack(app->net_out_queue, Ack_msg_Retval_DEBUG_ERROR);
        }
        else{
            send_ack(app->net_out_queue, Ack_msg_Retval_ACK);
        }
    }
}

/**
 * @brief Generator sub-app thread.
 * Waits for configuration and control messages.
 * 
 * @param p Generator sub-app instance pointer-
 */
void generator_app_thread(void *p){

    generator_app_t *app = (generator_app_t*) p;

    Base_msg received_message = Base_msg_init_zero;

    int exit = 0;

    while (!exit){
        /* Block until new incoming message */
	    xQueueReceive(app->net_in_queue,(void *) &received_message,portMAX_DELAY);

        /* Parse received messages */
        switch (received_message.which_message)
        {
        case Base_msg_config_tag:
            /* Is my config ? */
            if (received_message.config.which_config == Config_msg_generator_tag){
                /* Decode and set configuration */
                if (generator_app_decode_config(app, &received_message) < 0){
                    send_ack(app->net_out_queue, Ack_msg_Retval_BAD_CONFIG);
                }
                else {
                    send_ack(app->net_out_queue, Ack_msg_Retval_ACK);
                }
                
            }
            else{
                exit = 1;
                /* Received demodulator config, send message to main_app and exit thread */
				xQueueSend(app->main_app_queue, &received_message, portMAX_DELAY);
            }      
            break;
        
        case Base_msg_control_tag:
        	/* Broken conn?*/
        	if (received_message.control.command == Control_msg_Command_BROKEN_CONN){
                exit = 1;
            }
            else{
                generator_app_decode_control(app, &received_message);
            }
            break;

        default:
            print_info("%s: Unknown message received \r\n",__FUNCTION__);
            send_ack(app->net_out_queue, Ack_msg_Retval_INVALID_MSG);
            break;
        }

    }
    
    print_info("%s: Exiting task. \r\n",__FUNCTION__);
    generator_stop(&app->wg);   
    vTaskDelete(NULL);
}
