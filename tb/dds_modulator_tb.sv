`timescale 1ns / 1ps

import dds_modulator_pkg::*;

module dds_modulator_tb();
    parameter PERIOD_COUNTER_BITS = 15;
    logic [31:0] M_AXIS_DATA_0_tdata;
    logic M_AXIS_DATA_0_tvalid;
    logic M_AXIS_DATA_0_tready;

    /**
    * Inputs to dds_modulator
    */
    logic [31:0] config_reg_0 = 0;
    logic [31:0] config_reg_1 = 0;
    logic [31:0] config_reg_2 = 0;
    logic [31:0] config_reg_3 = 0;
    logic [31:0] config_reg_4 = 0;
    logic [31:0] config_reg_5 = 0;

    /**
    *   Test functions
    */

    // Enable/Disable
    function void modulator_enable(bit value);
        config_reg_0[ENABLE_BIT] = value;
    endfunction;
    
    // Enable/Disable Debug
    function void modulator_debug_enable(bit value);
        config_reg_0[DEBUG_BIT] = value;
    endfunction;

    // Set mode in config register
    function automatic void modulator_mode(input logic [STATE_BITS - 1 :0] mode);
        $display("OK");
       config_reg_1[STATE_BITS - 1 : 0] = mode;
    endfunction;

    // Configure PINC field for continuous frequency (f in MHz)
    function automatic void modulator_set_cont_freq(input int unsigned fout_MHz);
        automatic int unsigned pinc; 
        pinc = (fout_MHz * (2 ** PINC_BITS)) / FCLK_MHZ ;
        config_reg_3 [PINC_BITS-1:0] = pinc;
    endfunction;

    // Set frequency modulation values (f values in MHz, period length values in us)
    function automatic void modulator_set_frec_mod(int unsigned f_low_MHz,
                                                   int unsigned f_high_MHz,
                                                   int unsigned period_us);
        automatic int unsigned pinc_low; 
        automatic int unsigned pinc_high; 
        automatic int unsigned delta_pinc; 
        pinc_low = (f_low_MHz * (2 ** PINC_BITS)) / FCLK_MHZ ;
        pinc_high = f_high_MHz * ((2 ** PINC_BITS) / FCLK_MHZ) ;
        delta_pinc = (pinc_high - pinc_low) / (period_us * FCLK_MHZ);
        config_reg_3 [PINC_BITS-1:0] = pinc_low;
        config_reg_4 [PINC_BITS-1:0] = pinc_high;
        config_reg_5 [PINC_BITS-1:0] = delta_pinc;
    endfunction;

    // Set phase modulation values (frec values in MHz, subpulse length values in us)
    function automatic void modulator_set_phase_mod(int unsigned barker_code_num, 
                                                    int unsigned barker_subpulse_length_us,
                                                    int unsigned fout_MHz);
        automatic int unsigned pinc;

        // Set frequency
        pinc = (fout_MHz * (2 ** PINC_BITS)) / FCLK_MHZ ;
        config_reg_3 [PINC_BITS-1:0] = pinc;

        // Set subpulse length
        config_reg_4 [PINC_BITS-1:0] = (barker_subpulse_length_us * FCLK_MHZ) - 1;
        
        // Set barker code
        config_reg_5 [31:28] = barker_code_num;
        
        case(barker_code_num)
            2: config_reg_5 [13-1:0] = BARKER_2;     
            3:  config_reg_5 [13-1:0] = BARKER_3;
            4:  config_reg_5 [13-1:0] = BARKER_4;
            5:  config_reg_5 [13-1:0] = BARKER_5;
            7:  config_reg_5 [13-1:0] = BARKER_7;
            11:  config_reg_5 [13-1:0] = BARKER_11;
            13:  config_reg_5 [13-1:0] = BARKER_13;
            default: config_reg_5 [13-1:0] = 0;
        endcase
    endfunction;

    // Set period and pulse length for pulsed mode
    // Pulse length values in us
    function automatic void modulator_set_period(int unsigned pulse_us,
                                                 int unsigned period_us);
        config_reg_2 [30:16] = pulse_us * FCLK_MHZ;
        config_reg_2 [14:0] = period_us * FCLK_MHZ;
    endfunction;



    // Output is not x or z when valid is high
    DoutCheck: assert property (@(posedge clk_i)  (!$isunknown(M_AXIS_DATA_0_tdata)));

    /**
     * Clock & Initial Reset
     */

    parameter T_INITIAL_RESET = 20us;
    parameter T_BETWEEN_TESTS = 20us;

    logic clk_i = 0;
    logic resetn_i = 0;
    always #4 clk_i = !clk_i;
    initial #T_INITIAL_RESET resetn_i = 1;
    
    int unsigned pulse_length = 5;
    int unsigned barkerseq = 13;
    int unsigned subpulse_length = 5;

    initial M_AXIS_DATA_0_tready = 1'b1;
    
    initial begin
        #T_INITIAL_RESET
        
        /************************************
         * TEST: 1) Continuous frequency
         ************************************/

            modulator_mode(CONT_NO_MOD_TB);
            // 1 MHz
            modulator_set_cont_freq(1);
            modulator_enable(1);
            #20us
            // Freq change 10 MHz
            modulator_set_cont_freq(10);
            #20us 
            modulator_enable(0);
        
        /************************************
         * END TEST
         ************************************/

        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;
        
        /************************************************
         * TEST: 2) Continuous mode frequency modulated
         ************************************************/ 
            
            modulator_mode(CONT_MOD_FREC);
            // Inital freq 0MHz, End freq 5MHz, Length 50us
            modulator_set_frec_mod(0, 5, 100);
            modulator_enable(1);
            #200us
            modulator_enable(0);
        
        /************************************************
         * END TEST
         ************************************************/
        
        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;

        /************************************************
         * TEST: 3) Continuous mode phase modulated
         ************************************************/
        
            modulator_mode(CONT_MOD_PHASE);
            // Barker seq N° 5, 2us per subpulse, 1 MHz freq.
            modulator_set_phase_mod(5, 2, 1);
            modulator_enable(1);
            #200us
            modulator_enable(0);
        
        /************************************************
         * END TEST
         ************************************************/
        
        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;

        /************************************************
         * TEST: 4) Pulsed mode no modulation
         ************************************************/
            modulator_mode(PULS_NO_MOD_TB);
            // Pulse width 5 us, period 15 us
            modulator_set_period(5, 15);
            modulator_set_cont_freq(1);
            modulator_enable(1);       
            #300us
            modulator_enable(0);

        /************************************************
         * END TEST
         ************************************************/
        
        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;

        /************************************************
         * TEST: 5) Pulsed mode freq modulated
         ************************************************/
            modulator_mode(PULS_MOD_FREC);
            // Pulse width 5 us, period 15 us.
            pulse_length = 5;
            modulator_set_period(pulse_length, 15);
            // Freq sweep 0 to 20 MHz, in pulse_length
            modulator_set_frec_mod(0, 20, pulse_length);
            modulator_enable(1);
            #450us
            modulator_enable(0);

        /************************************************
         * END TEST
         ************************************************/
        
        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;

        /************************************************
         * TEST: 6) Pulsed mode phase modulated
         ************************************************/
            modulator_mode(PULS_MOD_PHASE);
            barkerseq = 13;         
            subpulse_length = 1;    
            modulator_set_period(barkerseq * subpulse_length, barkerseq * subpulse_length + 50);
            // 1MHz frequency
            modulator_set_phase_mod(barkerseq, subpulse_length, 1);
            modulator_enable(1);
            modulator_debug_enable(1);
            #300us
            modulator_enable(0);
            
        /************************************************
         * END TEST
         ************************************************/

        resetn_i = 0;
        #T_BETWEEN_TESTS
        resetn_i = 1;

        /************************************************
         * TEST: 7) Continuous frequency - Debug enabled
         ************************************************/
            
            modulator_debug_enable(1);
            modulator_mode(CONT_NO_MOD_TB);
            // 1 MHz
            modulator_set_cont_freq(1);
            modulator_enable(1);
            #20us
            // Freq change 10 MHz
            modulator_set_cont_freq(10);
            #20us 
            modulator_enable(0);
        
        /************************************************
         * END TEST
         ************************************************/
         #T_BETWEEN_TESTS
         /************************************************
         * TEST: 6) Pulsed mode phase modulated
         ************************************************/
            modulator_mode(PULS_MOD_PHASE);
            barkerseq = 7;         
            subpulse_length = 1;    
            modulator_set_period(barkerseq * subpulse_length, barkerseq * subpulse_length + 50);
            // 1MHz frequency
            modulator_set_phase_mod(barkerseq, subpulse_length, 1);
            modulator_enable(1);
            modulator_debug_enable(1);
            #300us
            modulator_enable(0);
         
         

        $finish;
    end

    logic [71:0] m_axis_modulation_tdata;
    logic m_axis_modulation_tvalid;
    logic m_axis_modulation_tready;


    /**
    *   DUT dds_modulator instance
    */

    dds_modulator DUT(
        .clk_i,
        .resetn_i,
        .dds_en_o(dds_en),
        .m_axis_modulation_tdata,
        .m_axis_modulation_tvalid,
        .m_axis_modulation_tready,
        .config_reg_0,
        .config_reg_1,
        .config_reg_2,
        .config_reg_3,
        .config_reg_4,
        .config_reg_5
    );
    
    /**
    *   DDS Compiler IP Wrapper
    */

    dds_compiler_bd_wrapper dds_compiler           
        (.M_AXIS_DATA_0_tdata,
        .M_AXIS_DATA_0_tready,   
        .M_AXIS_DATA_0_tvalid,
        .S_AXIS_PHASE_tdata(m_axis_modulation_tdata),
        .S_AXIS_PHASE_tvalid(m_axis_modulation_tvalid),
        .S_AXIS_PHASE_tready(m_axis_modulation_tready),  
        .aclk(clk_i),
        .aclken(dds_en),
        .aresetn(resetn_i));
  
endmodule
