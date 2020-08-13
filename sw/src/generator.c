#include "generator.h"
#include "FreeRTOS.h"
#include "task.h"

/* Buffer to store debug samples */
static u32 debug_samples[MAX_DEBUG_SAMPLES];

/**
 * @brief Reads a specific addres.
 * Wrapper of xilinx function, abstraction to read from generator registers
 * 
 * @param r Register address
 * @return uint32_t Register value
 */
static uint32_t _readReg(uint32_t r)
{
    return Xil_In32(r);
}

/**
 * @brief Writes to a specific addres.
 * Wrapper of xilinx function, abstraction to write from generator registers
 * 
 * @param addr Register Addres
 * @param data Data to be written
 */
static void _writeReg(uint32_t addr, uint32_t data)
{
    Xil_Out32(addr, data);
}

/**
 * @brief Read a specific bit value form the specified address.
 * 
 * @param addr Register Address
 * @param bit bit number (0 to 31)
 * @return uint32_t 0 if FALSE 1 if TRUE
 */
static uint32_t _readBit(uint32_t addr, uint32_t bit)
{
    /* Read entire reg */
    uint32_t temp = _readReg(addr);
    // Enmascaro el bit solicitado
    temp &= 1 << bit;
    // Devuelvo el valor
    return (temp ? 1 : 0);
}
/**
 * @brief 
 * 
 * @param addr Writes a specific bit value form the specified address.
 * @param bit bit number (0 to 31)
 * @param value Bit value (True/False, 1/0)
 */
static void _writeBit(uint32_t addr, uint32_t bit, uint32_t value)
{   
    /* Read current register value */
    uint32_t reg = _readReg(addr);

    /* Change actual bit */
    if (value)
    {
        reg = reg | (1 << bit);
    }
    else
    {
        reg = reg & ~(1 << bit);
    }

    /* Rewrite modified value */
    _writeReg(addr,reg);
}

void generator_init(Waveform_Generator_t * g, uint32_t hw_address, uint32_t axi_dma_device_id){
    /* Set everything to NULL */
    memset(g,0,sizeof(Waveform_Generator_t));
    // TODO: Validate address received is on Zynq valid addresses
    g->address = hw_address;
    g->axi_dma_device_id = axi_dma_device_id;
}

int generator_enable_debug(Waveform_Generator_t * wg){

	int Status;
    /* Init DMA */
    wg->axi_dma_cfg_ptr = XAxiDma_LookupConfig(wg->axi_dma_device_id);
    if (!wg->axi_dma_cfg_ptr) {
		return -1;
    }

    Status = XAxiDma_CfgInitialize(&wg->axi_dma_inst, wg->axi_dma_cfg_ptr);
	if (Status != SUCCESS) {
		return -1;
	}

    /* Init Debug Vector */
	memset(debug_samples,0,MAX_DEBUG_BYTES);
	
    /* Not working with interrupts yet. Not neccessary */
    XAxiDma_IntrDisable(&wg->axi_dma_inst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    
    wg->debug_enabled = 1;

    return 0;
}

int generator_start(Waveform_Generator_t * g){

    g->enabled = 1;

    _writeBit(g->address + REG_0_OFFSET, ENABLE_BIT, TRUE);

    return 0;
}

int generator_stop(Waveform_Generator_t * g){

    g->enabled = 0;

    _writeBit(g->address + REG_0_OFFSET, ENABLE_BIT, FALSE);

    return 0;
}

int generator_trigger_debug(Waveform_Generator_t * wg){
	
    int retval = 0;

    if (wg->enabled)
    {    
        Xil_DCacheFlushRange((UINTPTR)debug_samples, MAX_DEBUG_BYTES);

        /* Enable generator debug */
        _writeBit(wg->address + REG_0_OFFSET, DEBUG_BIT, TRUE);

        /* Start DMA transfer */
        int Status = XAxiDma_SimpleTransfer(&wg->axi_dma_inst,(UINTPTR) debug_samples, MAX_DEBUG_BYTES, XAXIDMA_DEVICE_TO_DMA);

        if (Status != XST_SUCCESS) {
            retval = -1;
        }
        
        /* Some debugging of DMA Registers */
        //    u32 stat = XAxiDma_ReadReg(wg->axi_dma_inst.RegBase + (XAXIDMA_RX_OFFSET * XAXIDMA_DEVICE_TO_DMA), XAXIDMA_SR_OFFSET);

        /* Wait and poll for DMA transfer end */
        while (retval == 0 && (XAxiDma_Busy(&wg->axi_dma_inst, XAXIDMA_DEVICE_TO_DMA)))
        {
            /* Wait 10 ms*/
            vTaskDelay(pdMS_TO_TICKS( 10 ));
        } 

        /* Some debugging of DMA Registers */
        //    u32 stat = XAxiDma_ReadReg(wg->axi_dma_inst.RegBase + (XAXIDMA_RX_OFFSET * XAXIDMA_DEVICE_TO_DMA), XAXIDMA_SR_OFFSET);
        //    u32 curdes = XAxiDma_ReadReg(wg->axi_dma_inst.RegBase + (XAXIDMA_RX_OFFSET * XAXIDMA_DEVICE_TO_DMA), XAXIDMA_CDESC_OFFSET);
        //    u32 destAdd = XAxiDma_ReadReg(wg->axi_dma_inst.RegBase + (XAXIDMA_RX_OFFSET * XAXIDMA_DEVICE_TO_DMA), XAXIDMA_DESTADDR_OFFSET);
        
        /* Read how many bytes were transfered by DMA*/
        u32 buffLen = XAxiDma_ReadReg(wg->axi_dma_inst.RegBase + (XAXIDMA_RX_OFFSET * XAXIDMA_DEVICE_TO_DMA), XAXIDMA_BUFFLEN_OFFSET);
        /* Transform number of bytes, to number of 32bit samples */
        wg->valid_debug_samples = buffLen / sizeof(u32);
        if (wg->valid_debug_samples == 0){
            retval = -1;
        }
    }
    else
    {
        retval = -1;
    }
    
	return retval;
}

/**
 * @brief Enables continuous mode
 * 
 * @param g Waveform generator instance
 * @return int 
 */
int _set_continuous(Waveform_Generator_t * g){
    g->mode = CONTINUOUS;
    _writeBit(g->address + REG_1_OFFSET, MODE_BIT, CONTINUOUS_MODE);
    return 0;
}

/**
 * @brief Enables pulsed mode
 * 
 * @param g Waveform Generator instance
 * @param period_us Period value in microseconds
 * @param pulse_length_us Pulse length value in microseconds
 * @return int -1 on ERROR, 0 on SUCCESS
 */
int _set_pulsed(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us){
    int retval = 0;
    
    /* Check wrong settings */
    if(period_us <= MAX_PERIOD_US &&
       period_us >= MIN_PERIOD_US &&
       pulse_length_us >= MIN_PULSE_LENGTH_US &&
       pulse_length_us < period_us)
    {
        g->mode = PULSED;
        _writeBit(g->address + REG_1_OFFSET, MODE_BIT, PULSED_MODE);

        g->period_us = period_us;
        g->pulse_length_us = pulse_length_us;    
    
        /* Align bits as required */
        /* Pulse length in high nibbles */
        /* Period in low nibbles */
        uint32_t pulse_data = (((g->pulse_length_us * FCLK_MHZ) & PERIOD_MASK) << 16) | (((g->period_us * FCLK_MHZ) & PERIOD_MASK));
        _writeReg(g->address + REG_2_OFFSET, pulse_data);
    
    }
    else
    {
        retval = -1;
    }    
    // Old 
    // g->period_us = (period_us < MIN_PERIOD_US) ? MIN_PERIOD_US :
    //                 (period_us > MAX_PERIOD_US) ? MAX_PERIOD_US :
    //                                                 period_us;

    // /* If wrong pulse_length, set it to 50% duty cycle */
    // if(pulse_length_us > period_us)
    //     g->pulse_length_us = g->period_us / 2;
    // else
    //     g->pulse_length_us = (pulse_length_us < MIN_PULSE_LENGTH_US) ? MIN_PULSE_LENGTH_US :
    //                         (pulse_length_us > MAX_PULSE_LENGTH_US) ? MAX_PULSE_LENGTH_US :
    //                                                                 pulse_length_us;
    return retval;
}

/**
 * @brief Disables modulation
 * 
 * @param g Waveform Generator instance
 * @return int 
 */
int _disable_modulation(Waveform_Generator_t * g){
    g->modulation_en = FALSE;
    _writeBit(g->address + REG_1_OFFSET, MODULATION_EN_BIT, FALSE);
    return 0;
}

/**
 * @brief Enables modulation
 * 
 * @param g Waveform generator instance
 * @return int 
 */
int _enable_modulation(Waveform_Generator_t * g){
    g->modulation_en = TRUE;
    _writeBit(g->address + REG_1_OFFSET, MODULATION_EN_BIT, TRUE);
    return 0;
}

/**
 * @brief Sets constant frequency values
 * 
 * @param g Waveform generator instance
 * @param freq_khz Frequency value in kilohertz
 * @return int 
 */
int _set_constant_freq(Waveform_Generator_t * g, uint32_t freq_khz){
    uint32_t pinc_val;
    int retval = 0;

    if (freq_khz <= MAX_FREQ_KHZ) {
        /* We received a valid frequency value */
        g->cont_freq_khz = freq_khz;
        /* Translate frequency val to pinc val */
        pinc_val = (g->cont_freq_khz * ((1U << PINC_BITS) / FCLK_KHZ)) & PINC_MASK;
        /* Write to Hw  */
        _writeReg(g->address + REG_3_OFFSET, pinc_val);
    }
    else {
        retval = -1;
    }
    
    return retval;
}

/**
 * @brief Sets frequency modulation parameters
 * 
 * @param g Waveform generator instance
 * @param low_freq_khz Initial frequency sweep value in kilohertz
 * @param high_freq_khz Final frequency sweep value in kilohertz
 * @param length_us Length in microseconds of the linear frequency sweep
 * @return int -1 on ERROR, 0 on SUCCESS
 */
int _set_frequency_modulation(Waveform_Generator_t * g, uint32_t low_freq_khz, uint32_t high_freq_khz, uint32_t length_us){
    int retval = 0;
    g->modulation_mode = FREQ_MOD;
    g->low_freq_khz = low_freq_khz;
    g->high_freq_khz = high_freq_khz;

    /* Check wrong settings */
    if (length_us <= MAX_PERIOD_US &&
        low_freq_khz <= MAX_FREQ_KHZ &&
        high_freq_khz <= MAX_FREQ_KHZ &&
        low_freq_khz <= high_freq_khz)
    {
        g->period_us = length_us;
        
        /* Translate frequency val to pinc val */
        uint32_t pinc_low_val = (g->low_freq_khz * ((1U << PINC_BITS) / FCLK_KHZ));
        uint32_t pinc_high_val = (g->high_freq_khz * ((1U << PINC_BITS) / FCLK_KHZ)) & PINC_MASK;
        uint32_t delta_pinc_val = ((pinc_high_val - pinc_low_val) / (g->period_us * FCLK_MHZ)) & PINC_MASK;
        g->delta_pinc = delta_pinc_val;

        /* Write to Hw  */
        _writeBit(g->address + REG_1_OFFSET, MODULATION_TYPE_BIT, g->modulation_mode);
        _writeReg(g->address + REG_3_OFFSET, pinc_low_val);
        _writeReg(g->address + REG_4_OFFSET, pinc_high_val);
        _writeReg(g->address + REG_5_OFFSET, g->delta_pinc);
    }
    else {
        retval = -1;
    }

    return retval;
}

/**
 * @brief Sets phase modulation parameters.
 * Phase modulation consists on 180° phase shifts according to Barker codes sequences.
 * 
 * @param g Waveform generator instance
 * @param freq_khz Constant frequency value in kilohertz
 * @param barker_seq Barker code number
 * @param subpulse_length_us Length in microseconds of 
 * @return int -1 on ERROR, 0 on SUCCESS
 */
int _set_phase_modulation(Waveform_Generator_t * g, uint32_t freq_khz, uint8_t barker_seq, uint32_t subpulse_length_us){
    int retval = 0;
    generator_stop(g);

    
    uint32_t barker_bits = 0;
    switch (barker_seq){
        case 2: barker_bits = BARKER_2; break;
        case 3: barker_bits = BARKER_3; break;
        case 4: barker_bits = BARKER_4; break;
        case 5: barker_bits = BARKER_5; break;
        case 7: barker_bits = BARKER_7; break;
        case 11: barker_bits = BARKER_11; break;
        case 13: barker_bits = BARKER_13; break;
        default: retval = -1; break;
    }

    if (retval == 0 &&
        freq_khz <= MAX_FREQ_KHZ &&
        subpulse_length_us >= MIN_BARKER_SUBPULSE_LENGTH_US &&
        (subpulse_length_us * barker_seq) <= MAX_PULSE_LENGTH_US) {
        
        g->modulation_mode = PHASE_MOD;
        g->barker_subpulse_length_us = subpulse_length_us;
        
        /* Translate subpulse length to register value */
        uint32_t barker_subpulse_length_reg_val = ((subpulse_length_us * FCLK_MHZ) - 1) & PINC_MASK;
        
        g->cont_freq_khz = freq_khz;

        /* Translate frequency val to pinc val */
        uint32_t pinc_val = (g->cont_freq_khz * ((1U << PINC_BITS) / FCLK_KHZ)) & PINC_MASK;
        
        /* Construct Config_reg_5 value */
        g->barker_seq_num = barker_seq;
        uint32_t barker_reg_val = (barker_seq << 28) | barker_bits; //TODO: Fix magic numbers

        /* Write to Hw  */
        _writeBit(g->address + REG_1_OFFSET, MODULATION_TYPE_BIT, PHASE_MOD);
        _writeReg(g->address + REG_4_OFFSET, barker_subpulse_length_reg_val);
        _writeReg(g->address + REG_5_OFFSET, barker_reg_val);
        _writeReg(g->address + REG_3_OFFSET, pinc_val);
    }
    else {
        retval = -1;
    }
    
    return retval;
}

int set_continuous_mode_constant_freq(Waveform_Generator_t * g, uint32_t freq_khz)
{
   generator_stop(g);
   _set_continuous(g);
   _disable_modulation(g);
   return(_set_constant_freq(g,freq_khz));
}

int set_continuous_mode_freq_mod(Waveform_Generator_t * g, uint32_t low_freq_khz, uint32_t high_freq_khz, uint32_t length_us){
    generator_stop(g);
    _set_continuous(g);
    _enable_modulation(g);
    return(_set_frequency_modulation(g,low_freq_khz,high_freq_khz,length_us));
}

int set_continuous_mode_phase_mod(Waveform_Generator_t * g, uint32_t freq_khz, uint8_t barker_seq_num, uint32_t barker_seq_length_us){
    int retval = 0;
    generator_stop(g);
    _set_continuous(g);
    _enable_modulation(g);
    retval = _set_phase_modulation(g, freq_khz, barker_seq_num, barker_seq_length_us/barker_seq_num); 
    return retval;
}

int set_pulsed_mode_constant_freq(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t freq_khz){
    int retval = 0;
    generator_stop(g);
    _disable_modulation(g);
    retval = _set_pulsed(g, period_us, pulse_length_us);
    if (retval < 0){
        return(retval);
    }
    else{
        retval = _set_constant_freq(g,freq_khz);
    }
    return(retval);
}

int set_pulsed_mode_freq_mod(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t low_freq_khz, uint32_t high_freq_khz){
    int retval = 0;
    generator_stop(g);
    _enable_modulation(g);

    retval = _set_pulsed(g, period_us, pulse_length_us);
    if (retval < 0)
    {
        return retval;
    }
    else
    {
        retval = _set_frequency_modulation(g, low_freq_khz, high_freq_khz, g->pulse_length_us);
    }
    return(retval);
}

int set_pulsed_mode_phase_mod(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t freq_khz, uint8_t barker_seq_num){
    int retval = 0;
    generator_stop(g);
    _enable_modulation(g);
    retval = _set_pulsed(g, period_us, pulse_length_us);
    if (retval < 0)
    {
        return retval;
    }
    else
    {
        retval = _set_phase_modulation(g, freq_khz, barker_seq_num, pulse_length_us/barker_seq_num);
    }  
    return retval;
}

/**
 * @brief Gets i samples from debug vector.
 * Cosine samples are in lower 16 bits of dds modulator output
 * Sine samples are in upper 16 bits of dds modulator output
 * [Sine|Cosine]
 * 
 * @param wg Waveform Generator instance
 * @param i_samples Output vector pointer
 * @param num_samples Amount of samples to copy
 */
void generator_get_i_samples(Waveform_Generator_t *wg, s32 *i_samples, u32 num_samples){

    /* Raw samples are in debug_samples global buffer*/
	s16 *samples = (s16*) debug_samples;

    for (u32 i = 0; i < num_samples ; i++){
        i_samples[i] = (s32) (samples[i*2]);
    }   
}

/**
 * @brief Gets q samples from debug vector.
 * Cosine samples are in lower 16 bits of dds modulator output
 * Sine samples are in upper 16 bits of dds modulator output
 * [Sine|Cosine]
 * 
 * @param wg Waveform Generator instance
 * @param q_samples Output vector pointer
 * @param num_samples Amount of samples to copy
 */
void generator_get_q_samples(Waveform_Generator_t *wg, s32 *q_samples, u32 num_samples){

    /* Raw samples are in debug_samples global buffer*/
	s16 *samples = (s16*) debug_samples;
    /* Shift 16 bits */ 
    samples++;

    for (u32 i = 0; i < num_samples ; i++){
        q_samples[i] = (s32) (samples[i*2]);
    }   
}
