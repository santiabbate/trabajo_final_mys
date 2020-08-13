#ifndef __MAIN_APP
#define __MAIN_APP

#include <stdio.h>
#include <string.h>

#include "lwip/sockets.h"
#include "netif/xadapter.h"
#include "lwipopts.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "task.h"

#include "generator_app.h"

#define THREAD_STACKSIZE 1024
#define MAX_QUEUED_MESSAGES 5

typedef struct{
   int accepted_sock;

   enum{
      MAIN,
      GENERATOR,
      DEMODULATOR
   } current_mode;

   /* Application queues */
   xQueueHandle main_queue;
   xQueueHandle generator_queue;
   xQueueHandle demodulator_queue;

   /* Network output data queue */
   xQueueHandle output_data_queue;
}main_app_t;

void send_ack(xQueueHandle queue, Ack_msg_Retval retval);

void main_app_thread(void *p);

int main_app_init(main_app_t *app);

#endif
