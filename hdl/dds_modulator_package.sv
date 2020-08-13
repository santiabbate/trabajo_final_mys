/**
 * @file dds_modulator_package.sv
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * Common definitions for DDS IP Core Modulator.
 */

package dds_modulator_pkg;

/* General params */
parameter FCLK_MHZ = 125;

/* Bit position definitions for config_reg_0 */
parameter ENABLE_BIT = 0;
parameter DEBUG_BIT = 1;

/**
 * config_reg_1 parameters 
 */
parameter STATE_BITS = 3;   //State is encoded in 3 bits
/* All pssible state configurations*/
parameter CONT_NO_MOD =     3'b?01;    
parameter CONT_MOD_FREC =   3'b111;
parameter CONT_MOD_PHASE =  3'b011;
parameter PULS_NO_MOD =     3'b?00;
parameter PULS_MOD_FREC =   3'b110;
parameter PULS_MOD_PHASE =  3'b010;
// Parameters used in testbenchs ('?' generates 'Z' values when applied to a signal)
parameter PULS_NO_MOD_TB =     3'b000;
parameter CONT_NO_MOD_TB =  3'b001;    

/**
 * config_reg_2 parameters 
 */
parameter PERIOD_COUNTER_BITS = 15;

/**
 * config_reg_3,4,5 parameters 
 */
parameter PINC_BITS = 30;   //This parameter should match with DDS IP Core configuration.

/**
 * Possible barker sequence values
 */
parameter BARKER_2 = 2'b10;
parameter BARKER_3 = 3'b110;
parameter BARKER_4 = 4'b1011;
parameter BARKER_5 = 5'b11101;
parameter BARKER_7 = 7'b1110010;
parameter BARKER_11 = 11'b11100010010;
parameter BARKER_13 = 13'b1111100110101;

/* Decimal value corresponding to a
 * 180° phase shift, when applied
 * to OFFSET configuration of DDS IP Core*/
parameter PHASE_OFFSET_180 = 536870911;

/* This value represents the maximum samples that will be retrieved through DMA */
parameter MAX_DEBUG_PACKETS = 125000;


endpackage