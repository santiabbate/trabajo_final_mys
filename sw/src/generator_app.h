#ifndef __GENERATOR_APP
#define __GENERATOR_APP

#include "FreeRTOS.h"
#include "queue.h"
#include "generator.h"
#include "messages.pb.h"

//#include "main_app.h"

#define MY_GENERATOR_ADDRESS XPAR_MM2S_DDS_MODULATOR_BASEADDR
#define DEBUG_DMA_ID XPAR_AXI_DMA_0_DEVICE_ID

typedef struct{
    Waveform_Generator_t wg;
    Base_msg incoming_message;
    
    /* Queue for incoming network messages*/
    xQueueHandle net_in_queue;
    /* Queue for main app communication */
    xQueueHandle main_app_queue;
    /* Network output data queue */
    /* This queue is initialized in main_app*/
    xQueueHandle net_out_queue;
}generator_app_t;

void generator_app_init (generator_app_t *app, Base_msg *first_message, xQueueHandle net_in_queue, xQueueHandle main_queue, xQueueHandle net_out_queue);

int generator_app_decode_config(generator_app_t *app, Base_msg *config_message);
void generator_app_decode_control(generator_app_t *app, Base_msg *config_message);

#endif
