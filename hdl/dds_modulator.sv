`timescale 1ns / 1ps
/**
 * @file dds_modulator.sv
 * @author Santiago Abbate
 * @brief CESE - Trabajo Final - Control de etapa digital de RADAR pulsado multipropósito.
 * DDS IP Core Modulator for RADAR Waveform generation.
 */


/**
 *  @param PINC_BITS: Phase increment accumulator bits in DDS IP Core
 *  @param PERIOD_COUNTER_BITS: Period Counter must count high enough to accomodate pulse length time
 *      Example @125MHz, 15 bit => Max pulse length = 262,136 us.
 */
module dds_modulator #(parameter PERIOD_COUNTER_BITS = 15, parameter PINC_BITS = 30)(
    input clk_i,
    input resetn_i,
    output dds_en_o,
    /* AXI-Stream bus for DDS IP Core configuration */
    output [71:0] m_axis_modulation_tdata,
    output m_axis_modulation_tvalid,
    output m_axis_modulation_tlast,
    input m_axis_modulation_tready,
    /* Configuration inputs from registers */
    input [31:0] config_reg_0,
    input [31:0] config_reg_1,
    input [31:0] config_reg_2,
    input [31:0] config_reg_3,
    input [31:0] config_reg_4,
    input [31:0] config_reg_5
    );
    
    import dds_modulator_pkg::*;

    /* Re-synchronization signal to Stall DDS to a fixed
     * value. Used to restart DDS output value to a known state */
    logic resync;

    /* Config register 0 signals */
    logic modulator_en;
    assign modulator_en = config_reg_0[ENABLE_BIT];

    logic dbg_en;
    assign dbg_en = config_reg_0[DEBUG_BIT];

    /* Config register 1 signals */
    logic pulsed_mode;
    assign pulsed_mode = config_reg_1[0];

    logic modulation_type;
    assign modulation_type = config_reg_1[2];
    parameter FREQ_MODULATION = 1;
    parameter PHASE_MODULATION = 0;
    
    logic [STATE_BITS-1:0] state_bits;
    assign  state_bits = config_reg_1[STATE_BITS-1:0];

    /* Config register 2 signals */
    logic [PERIOD_COUNTER_BITS-1:0] period; // For period length
    logic [PERIOD_COUNTER_BITS-1:0] tau; // For pulse length                         
    
    assign period = config_reg_2[PERIOD_COUNTER_BITS-1:0];
    assign tau = config_reg_2[PERIOD_COUNTER_BITS-1+16:16];

    /* Config register 3 signals */
    logic [29:0] pinc, pinc_low;

    assign pinc = config_reg_3[PINC_BITS-1:0];
    assign pinc_low = config_reg_3[PINC_BITS-1:0];

    /* Config register 4 signals */
    logic [PINC_BITS-1:0] barker_subpulse_length;
    logic [PINC_BITS-1:0] pinc_high;

    assign barker_subpulse_length = config_reg_4;
    assign pinc_high = config_reg_4[PINC_BITS-1:0];

    /* Config register 5 signals */
    logic [31:0] delta_pinc, barker_seq;

    assign delta_pinc = config_reg_5;
    assign barker_seq = config_reg_5;

    logic [3:0] barker_seq_num;
    assign barker_seq_num = config_reg_5[31:28];

    logic [12:0] barker_sequence;
    assign barker_sequence = config_reg_5[12:0];

    /* Output signal constructs */
    logic [29:0] tdata_pinc;
    logic [29:0] tdata_offset;
    logic tvalid;
    logic tlast;

    /* Signal to count the amount of debug samples thrown to the bus */
    logic [$clog2(MAX_DEBUG_PACKETS):0] packet_counter;
    
    /* Period counter for pulsed mode   */
    /*    ____                   ____   */
    /* __|    |_________________|    |__*/
    /*        ^                 ^       */
    /*     midcount(tau)       stop     */
    logic [PERIOD_COUNTER_BITS-1:0] period_counter_reg, period_counter_next;  
    logic [PERIOD_COUNTER_BITS-1:0] period_counter_stop, pulse_length;   
    logic period_counter_en;
    logic pulse_timeout_n;

    /**
     * Modulation counter for frequency modulated mode
     * and phase modulation mode (counts length of barker
     * code subpulses)
     */
    logic [PINC_BITS-1:0] modulation_counter_reg, modulation_counter_next, modulation_counter_start, modulation_counter_stop;
    logic modulation_counter_en;
    logic modulation_counter_counting_subpulse_length;     // Am I counting subpulse length? flag
    

    /**
     * Barker subpulse counter for phase modulated mode
     */
    logic [3:0] barker_subpulse_counter_reg, barker_subpulse_counter_next;
    logic barker_subpulse_counter_en;
    
    /* State logic decoding */
    always_comb
    begin
        /* Default values */
        modulation_counter_en = 0;
        modulation_counter_start = 0;
        modulation_counter_stop = 0;
        modulation_counter_counting_subpulse_length = 0;
        barker_subpulse_counter_en = 0;
        period_counter_en = 0;
        period_counter_stop = 0;
        pulse_length = 0;
        tdata_offset = 0;
        tdata_pinc = 0;
        tvalid = 1;

        casez(state_bits)
            CONT_NO_MOD:
                /* Continuous mode no modulation */
                begin
                    modulation_counter_en = 0;
                    period_counter_en = 0;
                    tdata_offset = 0;
                    /* Output constant PINC => Constant frequency */
                    tdata_pinc = pinc;
                end

            CONT_MOD_FREC:
                /* Continuous mode frequency modulated */
                begin
                    /* Modulation counter generates a linear PINC ramp */
                    modulation_counter_en = 1;
                    modulation_counter_start = pinc_low;
                    modulation_counter_stop = pinc_high;
                    period_counter_en = 0;
                    tdata_offset = 0;
                    tdata_pinc = modulation_counter_reg;
                end

            CONT_MOD_PHASE:
                /* Continuous mode phase modulated */
                begin
                    /* Modulation counter counts each barker subpulse length*/
                    modulation_counter_en = 1;
                    modulation_counter_start = 0;
                    modulation_counter_stop = barker_subpulse_length;
                    modulation_counter_counting_subpulse_length = 1;

                    /* Barker supulse counter tells wich barker bit is valid*/
                    barker_subpulse_counter_en = 1;
                    /* Phase offset is applied according to actual valid barker sequence bit */
                    tdata_offset = (barker_sequence[barker_subpulse_counter_reg]) ? 0 : PHASE_OFFSET_180;
                    /* Output constant PINC => Constant frequency */
                    tdata_pinc = pinc[29:0];

                    period_counter_en = 0;
                end

            PULS_NO_MOD:
                /* Pulsed mode without modulation */
                begin
                    /* Period counter counts pulse width and period */
                    period_counter_en = 1;
                    modulation_counter_en = 0;
                    period_counter_stop = period;
                    pulse_length = tau;
                    tdata_offset = 0;
                    /* Output constant PINC => Constant frequency */
                    tdata_pinc = pinc[29:0];
                end
            
            PULS_MOD_FREC:
                /* Pulsed mode frequency modulated */
                begin
                    /* Period counter counts pulse width and period */
                    period_counter_en = 1;
                    period_counter_stop = period;
                    pulse_length = tau;
                    /* Modulation counter generates a linear PINC ramp */
                    modulation_counter_en = pulse_timeout_n;
                    modulation_counter_start = pinc_low;
                    modulation_counter_stop = pinc_high;

                    tdata_offset = 0;
                    tdata_pinc = modulation_counter_reg;
                end

            PULS_MOD_PHASE:
                /* Pulsed mode phase modulated */
                begin
                    /* Period counter counts pulse width and period */
                    period_counter_en = 1;
                    period_counter_stop = period;
                    pulse_length = tau;
                    
                    /* Barker supulse counter tells wich barker bit is valid
                     * but gets disabled when pulse ends */
                    barker_subpulse_counter_en = pulse_timeout_n;

                    /* Modulation counter counts each barker subpulse length*/
                    modulation_counter_en = pulse_timeout_n;
                    modulation_counter_start = 0;
                    modulation_counter_stop = barker_subpulse_length;
                    modulation_counter_counting_subpulse_length = 1;

                    /* Phase offset is applied according to actual valid barker sequence bit */
                    tdata_offset = (barker_sequence[barker_subpulse_counter_reg]) ? 0 : PHASE_OFFSET_180;
                    /* Output constant PINC => Constant frequency */
                    tdata_pinc = pinc[29:0];
                    
                end
            default:
                begin
                    tvalid = 0;
                end    
        endcase
    end


    /*
     * Period counter logic
     */
    always_ff @(posedge clk_i)
    begin
        if (resetn_i == 0) period_counter_reg <= 0;
        else period_counter_reg <= period_counter_next;
    end

    always_comb // Next count logic
    begin 
        if (period_counter_reg == period_counter_stop) period_counter_next = 0; // Reset on max count
        else
        begin
            if (modulator_en & period_counter_en) period_counter_next = period_counter_reg + 1;   // Increment if enabled
            else    period_counter_next = period_counter_reg;
        end
    end
    
    // Pulse timeout goes to zero when period counter exceeds pulse length
    assign pulse_timeout_n = pulsed_mode ? 1 : (period_counter_reg < pulse_length);

    /*
     * Modulation counter logic
     */

    logic modulation_counter_expired;
    
    always_ff @(posedge clk_i)
    begin
        if (resetn_i == 0) begin
            modulation_counter_reg <= modulation_counter_start;
        end
        else begin
            modulation_counter_reg <= modulation_counter_next;
        end
    end

    always_comb
    begin
        modulation_counter_expired = 0;        
        if (modulator_en & modulation_counter_en) begin         
            if (modulation_counter_reg >= modulation_counter_stop) begin    // Reset to start count on max count
                modulation_counter_next = modulation_counter_start;
                modulation_counter_expired = 1;                             // We've expired -> Tell barker subpulse counter
            end
            else begin
                // Increment by 1 if counting barker subpulse length
                // Otherwise increment by delta_pinc, we're modulating frequency
                modulation_counter_next = modulation_counter_reg + (modulation_counter_counting_subpulse_length ? 1 : delta_pinc); 
            end
        end            
        else    modulation_counter_next = modulation_counter_start;
    end

    /*
     * Barker subpulse counter logic
     */
    
    // Este contador se incrementa de a uno para saber en qué subpulso estoy (Va de 1 a 13 como máximo)
    always_ff @(posedge clk_i)
    begin
        if (resetn_i == 0) begin
            barker_subpulse_counter_reg <= 0;
        end
        else begin
            if (barker_subpulse_counter_en) begin
                barker_subpulse_counter_reg <= barker_subpulse_counter_next;
            end
            else begin
                barker_subpulse_counter_reg <= 0;
            end
        end
    end

    always_comb
    begin
        if (modulation_counter_expired) begin         
            if (barker_subpulse_counter_reg == barker_seq_num - 1) begin
                barker_subpulse_counter_next = 0;
            end
            else begin
                barker_subpulse_counter_next = barker_subpulse_counter_reg + 1;
            end
        end
        else    barker_subpulse_counter_next = barker_subpulse_counter_reg;
    end

    // Envío una señal de resync al terminar un ciclo del pulso (Hubo timeout_n)
    assign resync = ~pulse_timeout_n & modulator_en;     
    
    // DDS is enabled whenever this modulator is enabled
    assign dds_en_o = modulator_en;     

    // AXI-Stream TLAST Circuit
    always_ff @(posedge clk_i)
    begin
        if (resetn_i == 0) begin
            packet_counter <= 0;
        end
        else
        begin
            if (m_axis_modulation_tready & modulator_en & dbg_en)
            begin
                if (packet_counter == MAX_DEBUG_PACKETS - 1)
                begin
                    packet_counter <= 0;
                end
                else 
                begin
                    packet_counter <= packet_counter + 1;
                end
            end
            else
            begin
                packet_counter <= 0;
            end
        end
    end

    assign tlast = (packet_counter == MAX_DEBUG_PACKETS - 1) ? 1 : 0;

    // AXI-Stream master output construct
    assign m_axis_modulation_tdata = {7'b0,resync,2'b00,tdata_offset,2'b00, resync ? 30'b0 : tdata_pinc};
    assign m_axis_modulation_tvalid = tvalid & modulator_en & m_axis_modulation_tready;
    assign m_axis_modulation_tlast = tlast;

endmodule