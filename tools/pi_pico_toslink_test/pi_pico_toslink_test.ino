#include <Arduino.h>
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "hardware/pio_instructions.h"

#define TX_PIN 2
#define RX_PIN 3
#define BTN_PIN 24

PIO pio = pio0;
uint sm_tx = 0;
uint sm_rx = 1;
uint offset_tx, offset_rx;


const float test_freqs[] = {
    0.001, // 1 kHz 
    0.010, // 10 kHz
    0.050, // 50 kHz 
    0.100, // 100 kHz
    0.250, 
    0.500, 
    1.000, 
    2.000, 
    5.000, 
    10.000, 
    15.000, 
    20.000, 
    25.000
};
const int num_freqs = sizeof(test_freqs) / sizeof(test_freqs[0]);
int current_freq_idx = 0;

enum Mode { AUTO_MODE, MANUAL_MODE };
Mode current_mode = AUTO_MODE;

const uint32_t test_patterns[] = {
    0x00000000, 
    0xFFFFFFFF, 
    0x55555555, 
    0x0F0F0F0F, 
    0x12345678  
};
const int num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);

void encode_manchester(uint32_t raw_data, uint32_t *out_m_low, uint32_t *out_m_high) {
    uint32_t m_low = 0, m_high = 0;
    for (int i = 0; i < 16; i++) {
        uint8_t bit = (raw_data >> i) & 1;
        if (bit) m_low |= (0b01 << (i * 2)); 
        else     m_low |= (0b10 << (i * 2));
    }
    for (int i = 0; i < 16; i++) {
        uint8_t bit = (raw_data >> (i + 16)) & 1;
        if (bit) m_high |= (0b01 << (i * 2));
        else     m_high |= (0b10 << (i * 2));
    }
    *out_m_low = m_low;
    *out_m_high = m_high;
}

void init_pio() {
    uint16_t tx_inst[] = {
        pio_encode_out(pio_pins, 1) | pio_encode_delay(3) 
    };
    struct pio_program tx_prog = { .instructions = tx_inst, .length = 1, .origin = -1 };
    offset_tx = pio_add_program(pio, &tx_prog);

    pio_sm_config c_tx = pio_get_default_sm_config();
    sm_config_set_out_pins(&c_tx, TX_PIN, 1);
    sm_config_set_set_pins(&c_tx, TX_PIN, 1);
    sm_config_set_out_shift(&c_tx, true, true, 32); 
    sm_config_set_wrap(&c_tx, offset_tx, offset_tx);
    pio_gpio_init(pio, TX_PIN);
    pio_sm_set_consecutive_pindirs(pio, sm_tx, TX_PIN, 1, true);
    pio_sm_init(pio, sm_tx, offset_tx, &c_tx);

    uint16_t rx_inst[] = {
        pio_encode_wait_pin(1, 0),                       
        pio_encode_nop() | pio_encode_delay(3),          
        pio_encode_jmp_pin(4),                           
        pio_encode_jmp(0),                               
        pio_encode_nop() | pio_encode_delay(3),          
        pio_encode_jmp_pin(7),                           
        pio_encode_jmp(0),                               
        pio_encode_wait_pin(0, 0),                       
        pio_encode_nop() | pio_encode_delay(3),          
        pio_encode_in(pio_pins, 1) | pio_encode_delay(2),
        pio_encode_jmp(9)                                
    };
    struct pio_program rx_prog = { .instructions = rx_inst, .length = 11, .origin = -1 };
    offset_rx = pio_add_program(pio, &rx_prog);

    pio_sm_config c_rx = pio_get_default_sm_config();
    sm_config_set_in_pins(&c_rx, RX_PIN);
    sm_config_set_jmp_pin(&c_rx, RX_PIN); 
    sm_config_set_in_shift(&c_rx, true, true, 32); 
    sm_config_set_wrap(&c_rx, offset_rx, offset_rx + 10);
    pio_gpio_init(pio, RX_PIN);
    pio_sm_set_consecutive_pindirs(pio, sm_rx, RX_PIN, 1, false);
    pio_sm_init(pio, sm_rx, offset_rx, &c_rx);
}

void set_frequency(float data_rate_mbps) {
    pio_sm_set_enabled(pio, sm_tx, false);
    pio_sm_set_enabled(pio, sm_rx, false);

    float baud_rate = data_rate_mbps * 2e6;
    float pio_freq = baud_rate * 4.0;
    float div = (float)clock_get_hz(clk_sys) / pio_freq;

    pio_sm_set_clkdiv(pio, sm_tx, div);
    pio_sm_set_clkdiv(pio, sm_rx, div);
    
    pio_sm_clear_fifos(pio, sm_tx);
    pio_sm_clear_fifos(pio, sm_rx);
    
    pio_sm_restart(pio, sm_tx);
    pio_sm_restart(pio, sm_rx);
    pio_sm_exec(pio, sm_tx, pio_encode_jmp(offset_tx));
    pio_sm_exec(pio, sm_rx, pio_encode_jmp(offset_rx));
    
    pio_sm_set_enabled(pio, sm_tx, true);
    pio_sm_set_enabled(pio, sm_rx, true);
}

bool button_pressed() {
    static uint32_t last_press = 0;
    if (digitalRead(BTN_PIN) == LOW) {
        if (millis() - last_press > 300) {
            last_press = millis();
            return true;
        }
    }
    return false;
}

void run_auto_test() {
    Serial.println("\n--- ROZPOCZĘCIE TESTU AUTO ---");
    for(int f = 0; f < num_freqs; f++) {
        if (current_mode != AUTO_MODE) break;
        
        float mbps = test_freqs[f];
        set_frequency(mbps);
        Serial.printf("\n[ Parametry: %6.3f Mbps Data / %6.3f Mbaud Wire ]\n", mbps, mbps*2);
        
        for(int p = 0; p < num_patterns; p++) {
            uint32_t raw = test_patterns[p];
            uint32_t m_low, m_high;
            encode_manchester(raw, &m_low, &m_high);
            
            for(int i=0; i<4; i++) {
                pio_sm_put_blocking(pio, sm_tx, 0x55555555); 
            }
            
            pio_sm_set_enabled(pio, sm_rx, false);
            pio_sm_clear_fifos(pio, sm_rx);
            pio_sm_restart(pio, sm_rx);
            pio_sm_exec(pio, sm_rx, pio_encode_jmp(offset_rx));
            pio_sm_set_enabled(pio, sm_rx, true);
            
            pio_sm_put_blocking(pio, sm_tx, 0x75555555); 
            pio_sm_put_blocking(pio, sm_tx, m_low);      
            pio_sm_put_blocking(pio, sm_tx, m_high);     
            
            uint32_t rx_low = 0, rx_high = 0;
            bool timeout = false;
            
            uint32_t max_wait = (mbps < 0.05) ? 1000 : 50; 
            
            uint32_t t = millis();
            while(pio_sm_is_rx_fifo_empty(pio, sm_rx)) {
                if(!pio_sm_is_tx_fifo_full(pio, sm_tx)) pio_sm_put(pio, sm_tx, 0x55555555);
                if(millis() - t > max_wait) { timeout = true; break; }
            }
            if(!timeout) rx_low = pio_sm_get(pio, sm_rx);
            
            t = millis();
            while(pio_sm_is_rx_fifo_empty(pio, sm_rx)) {
                if(!pio_sm_is_tx_fifo_full(pio, sm_tx)) pio_sm_put(pio, sm_tx, 0x55555555);
                if(millis() - t > max_wait) { timeout = true; break; }
            }
            if(!timeout) rx_high = pio_sm_get(pio, sm_rx);
            
            Serial.printf("  Wzorzec: 0x%08X -> ", raw);
            if(timeout) {
                Serial.println("BŁĄD (Timeout - Odbiornik nie zsynchronizował się)");
            } else if (rx_low == m_low && rx_high == m_high) {
                Serial.println("OK");
            } else {
                Serial.printf("BŁĄD (Oczekiwano: %08X %08X, Odebrano: %08X %08X)\n", m_low, m_high, rx_low, rx_high);
            }
            delay(10);
        }
    }
    Serial.println("------------------------------");
}

void run_manual_loop() {
    static uint32_t last_pattern_change = 0;
    static int p_idx = 0;
    
    if(millis() - last_pattern_change > 100) {
        p_idx = (p_idx + 1) % num_patterns;
        last_pattern_change = millis();
    }
    
    uint32_t raw = test_patterns[p_idx];
    uint32_t m_low, m_high;
    encode_manchester(raw, &m_low, &m_high);
    
    if(!pio_sm_is_tx_fifo_full(pio, sm_tx)) {
        pio_sm_put(pio, sm_tx, 0x75555555); 
        pio_sm_put(pio, sm_tx, m_low);
        pio_sm_put(pio, sm_tx, m_high);
        pio_sm_put(pio, sm_tx, 0x55555555); 
    }
    
    while(!pio_sm_is_rx_fifo_empty(pio, sm_rx)) {
        pio_sm_get(pio, sm_rx);
    }
}

void setup() {
    set_sys_clock_khz(200000, true); 
    
    Serial.begin(115200);
    pinMode(BTN_PIN, INPUT_PULLUP);
    while(!Serial);
    
    init_pio();
    Serial.println("System gotowy. Przycisk GPIO24 zmienia tryby.");
}

void loop() {
    if(button_pressed()) {
        if(current_mode == AUTO_MODE) {
            current_mode = MANUAL_MODE;
            current_freq_idx = 0;
            set_frequency(test_freqs[current_freq_idx]);
            Serial.printf("\n--- TRYB MANUALNY: %6.3f Mbps ---\n", test_freqs[current_freq_idx]);
        } else {
            current_freq_idx++;
            if(current_freq_idx >= num_freqs) {
                current_mode = AUTO_MODE;
                Serial.println("\n--- POWRÓT DO TRYBU AUTO ---");
            } else {
                set_frequency(test_freqs[current_freq_idx]);
                Serial.printf("\n--- TRYB MANUALNY: %6.3f Mbps ---\n", test_freqs[current_freq_idx]);
            }
        }
    }

    if(current_mode == AUTO_MODE) {
        run_auto_test();
        delay(3000); 
    } else {
        run_manual_loop();
    }
}