/**
 * @file main.c 
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito
 * Main file. Board and network initialization.
 * @date 2020-08-05
 */

#include <stdio.h>
#include "xparameters.h"
#include "netif/xadapter.h"
#include "platform_config.h"
#include "xil_printf.h"

#include "common.h"
#include "main_app.h"

int lwip_init_thread();
void print_app_header();

void lwip_init();

#define THREAD_STACKSIZE 1024

static struct netif server_netif;
struct netif *echo_netif;

/* Main App control structure */
main_app_t main_app;

static SemaphoreHandle_t mutex_uart_printf;

/**
 * @brief Thread safe printf
 */
void print_info(const char *format, ...){    
    
    va_list args;
    va_start(args, format);

    /* Take and give mutex for printing */
    if (pdTRUE == xSemaphoreTake( mutex_uart_printf, portMAX_DELAY)){
        vprintf(format,args);
        xSemaphoreGive( mutex_uart_printf );
    }
    va_end(args);
}

/* IP data printing helper func */
void print_ip(char *msg, ip_addr_t *ip)
{
	print_info(msg);
	print_info("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip),
			ip4_addr3(ip), ip4_addr4(ip));
}

/* IP settings printing helper func */
void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{

	print_ip("Board IP: ", ip);
	print_ip("Netmask : ", mask);
	print_ip("Gateway : ", gw);
	print_info("\r\n");
}

int main()
{   
    /* Printf Mutex Init */
    mutex_uart_printf = xSemaphoreCreateMutex();
    configASSERT( mutex_uart_printf );

    print_info("Application Init \r\n");

    /* Initial thread to initialize lwIP stack              */
    /* Main application will be started when network is up  */
	if (NULL == sys_thread_new("main_thrd", (void(*)(void*))lwip_init_thread, 0,
	                           THREAD_STACKSIZE,
	                           DEFAULT_THREAD_PRIO)){
        print_info("%s: Error creating lwip_init_thread",__FUNCTION__);
    }
    else{
	    vTaskStartScheduler();
    }

	while(1);
	return 0;
}

/**
 * @brief Board network interface configuration and initialization.
 *  
 */
void network_thread(void *p)
{
    int error = 0;
    struct netif *netif;
    /* The mac address of the board */
    unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

    ip_addr_t ipaddr, netmask, gw;

    netif = &server_netif;

    /* Initialize IP addresses to be used */
    IP4_ADDR(&ipaddr,  192, 168, 1, 10);
    IP4_ADDR(&netmask, 255, 255, 255,  0);
    IP4_ADDR(&gw,      192, 168, 1, 1);

    /* Add network interface to the netif_list, and set it as default */
    /* This Xilinx provided function internally starts a thread to detect link periodically for Hot Plug autodetect */
    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_ethernet_address, PLATFORM_EMAC_BASEADDR)) {
        print_info("Error adding N/W interface\r\n");
        error = -1; 
    }

    if (!error){

        /* Tell lwIP that the network ineterface is up */
        netif_set_default(netif);
        netif_set_up(netif);

        /* Start packet receive thread - required for lwIP operation */
        /* xemacif_input_thread is part of lwIP Xilinx port */
        if (NULL == sys_thread_new("xemacif_input_thread", (void(*)(void*))xemacif_input_thread, netif,
                                    THREAD_STACKSIZE,
                                    DEFAULT_THREAD_PRIO)){
            print_info("%s: Fatal Error creating xemacif_input_thread",__FUNCTION__);
        }
        else{
            /* Network is up --> Launch main application */
            print_app_header();
            /* Print out IP settings of the board */
            print_ip_settings(&ipaddr, &netmask, &gw);
            
            main_app = (main_app_t){0};
            if(main_app_init(&main_app) < 0){
                print_info("ERROR: Main App couldn't launch\r\n");
            }
        }
    }

    vTaskDelete(NULL);
    return;
}

/**
 * @brief lwIP stack initilization thread.
 * lwIP must be started before any other tasks.
 */
int lwip_init_thread()
{
	/* Initialize lwIP before starting new tasks */
    lwip_init();

    /* Launch Network PHY initialization thread */
    if(NULL == sys_thread_new("NW_THRD", network_thread, NULL,
		                    THREAD_STACKSIZE,
                            DEFAULT_THREAD_PRIO)){

        print_info("%s: Error creating network_thread",__FUNCTION__);
    }

    /* Nothing more to do. When Network PHY is up, main application will be launched */
    vTaskDelete(NULL);
    return 0;
}
