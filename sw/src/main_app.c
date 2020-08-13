/**
 * @file main_app.c
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * Main application app. Receives configuration and control messagges, and
 * launches sub-applications accordingly.
 * @date 2020-08-09 
 */

#include <stdio.h>
#include <string.h>

#include "lwip/sockets.h"
#include "netif/xadapter.h"
#include "lwipopts.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "task.h"

#include "common.h"
#include "main_app.h"
#include "generator_app.h"

#include "pb_common.h"
#include "pb_encode.h"
#include "pb_decode.h"
#include "messages.pb.h"

#define RECV_BUF_SIZE 2048

/* Application network port */
u16_t app_port = 7;

/* Protobuf message for generator debug samples */
extern Debug_msg debug_samples_msg;
/* Buffer for network output stream (Protobuf encoded messages) */
uint8_t out_buffer[Debug_msg_size];

void incoming_data_thread(void *p);
void output_data_thread(void *p);

void print_app_header()
{
    print_info("\r\n");
    print_info("-----------------------------------\n");
    print_info("CESE - Radar digital\n");
    print_info("-----------------------------------\n");
}

/**
 * @brief Helper function for ack messages sending.
 * 
 * @param queue Message queue handle.
 * @param retval Protobuf Ack message to send.
 */
void send_ack(xQueueHandle queue, Ack_msg_Retval retval){
	Base_msg ack_message = Base_msg_init_zero;

	ack_message.which_message = Base_msg_ack_tag;
	ack_message.ack.retval = retval;
	xQueueSend(queue, &ack_message, portMAX_DELAY);
}

/**
 * @brief Main application thread.
 * Accepts socket connection, and spawns Generator and Demodulator sub-apps.
 * 
 * @param p Main application control struct pointer.
 */
void main_app_thread(void *p)
{
	int error = 0;
	main_app_t *app = (main_app_t*) p;

	/* Generator sub-application */
	static generator_app_t generator_app;

	/* Protobuf messages vars */
	Base_msg received_message = Base_msg_init_zero;

	/* Socket related vars */
	int sock;
	int size;
	struct sockaddr_in address, remote;
	
	/* Init sockaddr struct */
	memset(&address, 0, sizeof(address));

	/* Create socket */
	if ((sock = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0)
		error = -1;

	address.sin_family = AF_INET;
	address.sin_port = htons(app_port);
	address.sin_addr.s_addr = INADDR_ANY;

	/* Socket bind */
	if (lwip_bind(sock, (struct sockaddr *)&address, sizeof (address)) < 0)
		error = -1;

	lwip_listen(sock, 0);

	size = sizeof(remote);

	while (!error) {
		/* Accept new connection 
		 * Only one simultaneous connection allowed */
		if ((app->accepted_sock = lwip_accept(sock, (struct sockaddr *)&remote, (socklen_t *)&size)) > 0) {

			/* Create Data reception task */
			if(NULL == sys_thread_new("incoming_data_thread",
									  incoming_data_thread,
									  (void*)app,
									  THREAD_STACKSIZE,
									  DEFAULT_THREAD_PRIO)){
				print_info("%s: Error creating incoming_data_thread\r\n",__FUNCTION__);
				error = -1;
				continue;
			}
			
			/* Create Data output task */
			if(NULL == sys_thread_new("output_data_thread",
									  output_data_thread,
									  (void*)app,
									  THREAD_STACKSIZE,
									  DEFAULT_THREAD_PRIO)){
				print_info("%s: Error creating output_data_thread\r\n",__FUNCTION__);
				error = -1;
				continue;
			}

			print_info("%s: New connection \r\n",__FUNCTION__);
			while(1){
				/* Connection is up, wait for incoming messages */
				xQueueReceive(app->main_queue,(void *) &received_message,portMAX_DELAY);
				
				/* If new config arrived */
				if (received_message.which_message == Base_msg_config_tag){
					
					/* Create app and launch task */
					if (received_message.config.which_config == Config_msg_generator_tag){
						print_info("%s: Creating generator app \r\n",__FUNCTION__);
						generator_app_init(&generator_app, &received_message, app->generator_queue, app->main_queue, app->output_data_queue);
						app->current_mode = GENERATOR;
						/* Return ack */
						send_ack(app->output_data_queue, Ack_msg_Retval_ACK);
					}
					else if (received_message.config.which_config == Config_msg_demodulator_tag){
						print_info("Creating demodulator app \r\n");
						app->current_mode = DEMODULATOR;
					}
					else{
						print_info("%s: Received bad config \r\n",__FUNCTION__);
						send_ack(app->output_data_queue, Ack_msg_Retval_BAD_CONFIG);
					}
					
				}
				else if (received_message.which_message == Base_msg_control_tag){
					if (received_message.control.command == Control_msg_Command_BROKEN_CONN){
						print_info("%s: Connection is down, waiting new connect. \r\n",__FUNCTION__);
						break;
					}
					print_info("%s: Received command when no config applied \r\n",__FUNCTION__);
					/* Return ack */
					send_ack(app->output_data_queue, Ack_msg_Retval_NO_CONFIG);
				}
				else{
					print_info("%s: Unknown message received \r\n",__FUNCTION__);
				}	
			}

			/* Out of main loop, BROKEN_CONN Command received */
			/* Other apps are deleted, we're back to MAIN app */
			app->current_mode = MAIN;
		}
	}

	print_info("ERROR %s: Deleting main app\r\n",__FUNCTION__);
	vTaskDelete(NULL);
}

/**
 * @brief Data reception task.
 * Receives messages from socket, decodes protobuf messages and
 * sends them to corresponding sub-app.
 * 
 * @param p Main application control struct pointer
 */
void incoming_data_thread(void *p){

	main_app_t *app = (main_app_t*) p;

	/* Socket related vars */
	int sock = app->accepted_sock;
	int n;
	char recv_buf[RECV_BUF_SIZE];

	/* Protobuf messages vars */
	Base_msg incoming_msg = Base_msg_init_zero;
	pb_istream_t input_stream;
	Base_msg output_msg = Base_msg_init_zero;

	while(1){
		if ((n = read(sock, recv_buf, RECV_BUF_SIZE)) < 0) {
			print_info("%s: Error reading from socket %d, closing socket\r\n", __FUNCTION__, sock);
			break;
		}

		/* Build nano-pb input stream from received bytes (n) */		
		input_stream = pb_istream_from_buffer((pb_byte_t*)recv_buf, n);

		/* Dispatch received message to sub-app, if valid */
		if (pb_decode(&input_stream, Base_msg_fields, &incoming_msg) && n != 0){
			switch (app->current_mode){
				case MAIN:
					xQueueSend(app->main_queue, &incoming_msg, portMAX_DELAY);
					break;
				case GENERATOR:
					xQueueSend(app->generator_queue, &incoming_msg, portMAX_DELAY);
					break;
				case DEMODULATOR:
					xQueueSend(app->demodulator_queue, &incoming_msg, portMAX_DELAY);
					break;
				default:
					xQueueSend(app->main_queue, &incoming_msg, portMAX_DELAY);
					break;
			}
		}
		/* Handle invalid message */
		else if (n != 0)
		{
			/* Return invalid message */
			output_msg.which_message = Base_msg_ack_tag;	
			output_msg.ack.retval = Ack_msg_Retval_INVALID_MSG;
			print_info("%s: No valid message received\r\n", __FUNCTION__);

			xQueueSend(app->output_data_queue, &output_msg, portMAX_DELAY);
		}
	}

	/* Socket read returned error:           */
	/* Notify apps that connection is closed */
	output_msg.which_message = Base_msg_control_tag;
	output_msg.control.command = Control_msg_Command_BROKEN_CONN;
	/* Send to output_data_thread */
	xQueueSend(app->output_data_queue, &output_msg, portMAX_DELAY);
	/* Send to Main app */
	xQueueSend(app->main_queue, &output_msg, portMAX_DELAY);
	/* Send to Current sub-app */
	if(app->current_mode == GENERATOR){
		xQueueSend(app->generator_queue, &output_msg, portMAX_DELAY);
	}
	else if (app->current_mode == DEMODULATOR) {
		xQueueSend(app->demodulator_queue, &output_msg, portMAX_DELAY);
	}

	/* Close connection */
	close(sock);
	/* Nothing to do until new connection, delete task */
	vTaskDelete(NULL);
}

/**
 * @brief Data output task.
 * Writes encoded protobuf outgoing messages to socket.
 * 
 * @param p Main application control struct pointer
 */
void output_data_thread(void *p){

	main_app_t *app = (main_app_t*) p;

	/* Socket related vars */
	int sock = app->accepted_sock;
	int nwrote;

	/* Protobuf messages vars */
	Base_msg output_msg = Base_msg_init_zero;
	pb_ostream_t output_stream;
	int message_length;

	int status;

	while(1){
		
		/* Wait for messages to send */
		xQueueReceive(app->output_data_queue,(void *) &output_msg, portMAX_DELAY);

		/* Build nano-pb output stream for encoded messages as bytes */
		output_stream = pb_ostream_from_buffer(out_buffer, sizeof(out_buffer));

		/* Encode message */
		status = pb_encode(&output_stream, Base_msg_fields, &output_msg);
		message_length = output_stream.bytes_written;

		/* Send to network if encoded OK*/
		if(status & (message_length != 0)){
			
			/* Check if connection is broken */
			if (output_msg.which_message == Base_msg_control_tag && output_msg.control.command == Control_msg_Command_BROKEN_CONN){
				break;
			}

			/* Check if we've to send debug samples */
			if (output_msg.which_message == Base_msg_ack_tag && output_msg.ack.retval == Ack_msg_Retval_DEBUG_IS_VALID)
			{
				/* Build again output stream with debug message - This overwrites output stream */
				status = pb_encode(&output_stream, Debug_msg_fields, &debug_samples_msg);
				message_length = output_stream.bytes_written;
				if (!status)
				{
					print_info("%s: Could not encode debug message to serialize", __FUNCTION__);
					continue;
				}			
			}

			/* Out Message is encoded as bytes, send it through socket */
			if ((nwrote = write(sock, out_buffer, message_length)) < 0) {
				print_info("%s: Error sending output message. Bytes to write = %d, Bytes written = %d\r\n",
						__FUNCTION__, message_length, nwrote);
			}
		}
		else{
			print_info("%s: Could not encode message to serialize", __FUNCTION__);
		}
		
	}

	/* BROKEN_CONN message received */
	/* Nothing to do until new connection, delete task */
	vTaskDelete(NULL);
}

/**
 * @brief Initialize main app structure
 * 
 * @param app Main Application instance pointer
 * @return int -1 on ERROR 0 on SUCCESS
 */
int main_app_init(main_app_t *app){

	*app = (main_app_t){0};

	/* Queues */
	/* Main app input protobuf messages queue*/
	if (!(app->main_queue = xQueueCreate(MAX_QUEUED_MESSAGES, sizeof(Base_msg)) )){
		return -1;
	}
	
	/* Generator sub-app input protobuf messages queue*/
	if (!(app->generator_queue = xQueueCreate(MAX_QUEUED_MESSAGES, sizeof(Base_msg)) )){
		return -1;
	}

	/* Demodulator sub-app input protobuf messages queue*/
	if (!(app->demodulator_queue = xQueueCreate(MAX_QUEUED_MESSAGES, sizeof(Base_msg)) )){
		return -1;
	}

	/* Main app output protobuf messages queue*/
	if (!(app->output_data_queue = xQueueCreate(MAX_QUEUED_MESSAGES, sizeof(Base_msg)) )){
		return -1;
	}

	/* Application starts in MAIN mode,
	 * Generator and Demodulator sub-apps
	 * are created later depending on 
	 * commands received
	 * */
	app->current_mode = MAIN;

	/* Create main application task */
	if (NULL == (sys_thread_new("main_app", main_app_thread, app,
								THREAD_STACKSIZE,
								DEFAULT_THREAD_PRIO))){
		return -1;	
	}
	else{
		return 0;
	}
}

