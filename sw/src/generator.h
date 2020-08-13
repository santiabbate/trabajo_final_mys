#include <xil_io.h>
#include "xaxidma.h"

#define ERROR 1
#define SUCCESS 0

#define REG_0_OFFSET 0x0
#define REG_1_OFFSET 0x4
#define REG_2_OFFSET 0x8
#define REG_3_OFFSET 0xc
#define REG_4_OFFSET 0x10
#define REG_5_OFFSET 0x14


#define FCLK_MHZ    125U
#define FCLK_KHZ    (FCLK_MHZ * 1000)
#define FCLK        (FCLK_KHZ * 1000)


/* Reg 0 defines */
#define ENABLE_BIT 0
#define DEBUG_BIT 1
/* Reg 1 defines */
#define MODE_BIT 0
#define MODULATION_EN_BIT 1
#define CONTINUOUS_MODE 1
#define PULSED_MODE 0
#define MODULATION_TYPE_BIT 2
#define FREQ_MOD 1
#define PHASE_MOD 0

/* Reg 2 defines */
#define PERIOD_COUNTER_BITS 15
#define PERIOD_MASK ((1U << (PERIOD_COUNTER_BITS)) - 1)
#define MAX_PERIOD_US 250
#define MAX_PULSE_LENGTH_US 200
#define MIN_PULSE_LENGTH_US 5
#define MIN_PERIOD_US 5 + MIN_PULSE_LENGTH_US
#define MIN_BARKER_SUBPULSE_LENGTH_US 1

/* Reg 3 defines */
#define PINC_BITS 30
#define PINC_MASK ((1U << (PINC_BITS)) - 1)
#define MAX_FREQ_KHZ 20000

/* Reg 5 defines */
#define BARKER_2 2;
#define BARKER_3 6;
#define BARKER_4 11;
#define BARKER_5 29;
#define BARKER_7 114;
#define BARKER_11 1810;
#define BARKER_13 7989;

/* Debug defines */
#define MAX_DEBUG_SAMPLES 125000
#define MAX_DEBUG_BYTES MAX_DEBUG_SAMPLES * sizeof(u32)

typedef enum mode{
    CONTINUOUS,
    PULSED
    // CONT_NO_MOD,
    // CONT_MOD_FREC,
    // CONT_MOD_PHASE,
    // PULS_NO_MOD,
    // PULS_MOD_FREC,
    // PULS_MOD_PHASE
}generator_mode_t;

typedef struct Waveform_Generator
{
    uint32_t address;
    uint8_t enabled;
    uint8_t debug_enabled;  //TODO: Ver si hace falta
    generator_mode_t mode;
    uint8_t modulation_en;
    uint8_t modulation_mode;

    /* Continuous mode attributes */
    uint32_t cont_freq_khz;
    /* Pulsed mode Attributes */
    uint32_t period_us;
    uint32_t pulse_length_us;
    /* Frequency modulation attributes */
    uint32_t low_freq_khz;
    uint32_t high_freq_khz;
    uint32_t delta_pinc;

    /* Phase mode attributes */
    uint32_t barker_subpulse_length_us;
    uint8_t barker_seq_num;

    uint8_t bad_config;

    /* Debug attributes */
    u32 axi_dma_device_id;
    XAxiDma axi_dma_inst;
    XAxiDma_Config *axi_dma_cfg_ptr;
    u32 *debug_samples_ptr;
    u32 valid_debug_samples;

}Waveform_Generator_t;

/**
 * @brief Maps an instance of a waveform generator to an address location
 * 
 * @param g Waveform Generator instance
 * @param address Hardware address of memory mapped AXI waveform generator
 * @param axi_dma_device_id Hardware address of memory mapped AXI-DMA IP Core for samples debugging
 */
void generator_init(Waveform_Generator_t * g, uint32_t hw_address, uint32_t axi_dma_device_id);

/**
 * @brief Enables debug. Important: Debug mode will be disabled
 * when all samples are transfered.
 * 
 * @param g Waveform Generator instance
 * @return int -1 on ERROR, 0 on SUCCESS
 */
int generator_enable_debug(Waveform_Generator_t * g);

/**
 * @brief Enables and starts operation of the waveform generator
 * 
 * @param g Waveform Generator instance
 * @return int 
 */
int generator_start(Waveform_Generator_t * g);


/**
 * @brief Enables and starts operation of the waveform generator
 * 
 * @param g Waveform Generator instance
 */
int generator_stop(Waveform_Generator_t * g);

/**
 * @brief Sets Waveform Generator to continuous mode and configures constant frequency operation.
 * No modulation will be applied in this mode
 * After configuration the core will remain disabled.
 * 
 * @param g Waveform Generator instance
 * @param freq_khz Frequency in kHz
 * @return int 
 */
int set_continuous_mode_constant_freq(Waveform_Generator_t * g, uint32_t freq_khz);

/**
 * @brief Sets Waveform Generator to continuous mode and configures frequency modulation operation.
 * Available modulation is Linear FM Upchirp
 * After configuration the core will remain disabled.
 * 
 * @param g Waveform Generator instance
 * @param low_freq_khz Low frequency of the chirp signal in kHz
 * @param high_freq_khz High frequency of the chirp signal in kHz
 * @param length_us Length of the upchirp in us
 * @return int 
 */
int set_continuous_mode_freq_mod(Waveform_Generator_t * g, uint32_t low_freq_khz, uint32_t high_freq_khz, uint32_t length_us);

/**
 * @brief Sets Waveform Generator to continuous mode and configures phase modulation operation.
 * Available modulation is Barker Phase Code modulation:
 * Codes available: 2, 3, 4, 5, 7, 11, 13 (default is 13)
 * 
 * @param g Waveform Generator instance
 * @param freq_khz Frequency in kHz
 * @param barker_seq_num Barker code number
 * @param barker_seq_length_us Total sequence length
 * @return int 
 */
int set_continuous_mode_phase_mod(Waveform_Generator_t * g, uint32_t freq_khz, uint8_t barker_seq_num, uint32_t barker_seq_length_us);

/**
 * @brief Sets Waveform Generator to pulsed mode and configures configures constant frequency operation.
 * No modulation will be applied in this mode
 * After configuration the core will remain disabled.
 *  
 * @param g Waveform Generator instance
 * @param period_us Period in microseconds (In RADAR terms, Pulse Repetition Interval)
 * @param pulse_length_us  Pulse length in microseconds
 * @param freq_khz Frequency in kHz
 * @return int 
 */
int set_pulsed_mode_constant_freq(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t freq_khz);

/**
 * @brief Sets Waveform Generator to pulsed mode and configures frequency modulation operation.
 * Available modulation is Linear FM Upchirp
 * After configuration the core will remain disabled.
 * 
 * @param g Waveform Generator instance
 * @param period_us Period in microseconds (In RADAR terms, Pulse Repetition Interval)
 * @param pulse_length_us Pulse length in microseconds
 * @param low_freq_khz Low frequency of the chirp signal in kHz
 * @param high_freq_khz High frequency of the chirp signal in kHz
 * @return int 
 */
int set_pulsed_mode_freq_mod(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t low_freq_khz, uint32_t high_freq_khz);

/**
 * @brief Sets Waveform Generator to pulsed mode and configures phase modulation operation.
 * Available modulation is Barker Phase Code modulation:
 * Codes available: 2, 3, 4, 5, 7, 11, 13 (default is 13)
 * 
 * @param g Waveform Generator instance
 * @param period_us Period in microseconds (In RADAR terms, Pulse Repetition Interval)
 * @param pulse_length_us Pulse length in microseconds
 * @param freq_khz Frequency in kHz
 * @param barker_seq_num Barker code number
 * @return int 
 */
int set_pulsed_mode_phase_mod(Waveform_Generator_t * g, uint32_t period_us, uint32_t pulse_length_us, uint32_t freq_khz, uint8_t barker_seq_num);

/**
 * @brief Triggers debug samples transfer form PL to PS.
 * Debug enable bit will return to 0 when all samples are transferd
 * 
 * @param wg Waveform Generator instance
 * @return int -1 on ERROR, 0 on SUCCESS
 */
int generator_trigger_debug(Waveform_Generator_t * wg);


void generator_get_i_samples(Waveform_Generator_t *wg, s32 *i_samples, u32 num_samples);
void generator_get_q_samples(Waveform_Generator_t *wg, s32 *q_samples, u32 num_samples);
