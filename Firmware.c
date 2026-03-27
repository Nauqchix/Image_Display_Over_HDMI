#include <stdint.h>

#define PERIPH_BASE      0xF0000000u
#define RAM_BASE         0x40000000u

#define HDMI_ENABLE      (*(volatile uint32_t*)(PERIPH_BASE + 0x00))
#define FB_BASE_WORD     (*(volatile uint32_t*)(PERIPH_BASE + 0x04))
#define REG_STATUS       (*(volatile uint32_t*)(PERIPH_BASE + 0x08))
#define LED_CTRL         (*(volatile uint32_t*)(PERIPH_BASE + 0x0C))
#define UART_DATA        (*(volatile uint32_t*)(PERIPH_BASE + 0x10))
#define UART_STATUS      (*(volatile uint32_t*)(PERIPH_BASE + 0x14))

#define IMG_W            300u
#define IMG_H            300u
#define IMG_PIXELS       (IMG_W * IMG_H)
#define IMG_WORDS        (IMG_PIXELS / 2u)
#define FB_WORD_OFFSET   32768u

#define UART_READY_MASK    0x1u
#define UART_OVERRUN_MASK  0x2u

static inline void led_set(uint32_t value) {
    LED_CTRL = value & 0x3u;
}

static inline void uart_clear_overrun(void) {
    UART_STATUS = 1u;
}

static uint8_t uart_getc_blocking(void) {
    while ((UART_STATUS & UART_READY_MASK) == 0u) {
    }
    return (uint8_t)(UART_DATA & 0xFFu);
}

static void fill_solid_rgb565(uint16_t color) {
    volatile uint32_t *fb = (volatile uint32_t *)(RAM_BASE + FB_WORD_OFFSET * 4u);
    uint32_t i;
    uint32_t packed = (uint32_t)color | ((uint32_t)color << 16);

    for (i = 0; i < IMG_WORDS; i++) {
        fb[i] = packed;
    }
}

static void wait_for_img1_header(void) {
    uint32_t shift = 0u;
    for (;;) {
        shift = (shift >> 8) | ((uint32_t)uart_getc_blocking() << 24);
        if (shift == 0x31474D49u) { // 'I''M''G''1' in receive order
            return;
        }
    }
}

static int receive_image_packet(void) {
    volatile uint16_t *fb16 = (volatile uint16_t *)(RAM_BASE + FB_WORD_OFFSET * 4u);
    uint32_t i;
    uint16_t width;
    uint16_t height;

    wait_for_img1_header();

    width  = (uint16_t)uart_getc_blocking();
    width |= (uint16_t)uart_getc_blocking() << 8;
    height  = (uint16_t)uart_getc_blocking();
    height |= (uint16_t)uart_getc_blocking() << 8;

    if (width != IMG_W || height != IMG_H) {
        return 0;
    }

    for (i = 0; i < IMG_PIXELS; i++) {
        uint16_t lo = (uint16_t)uart_getc_blocking();
        uint16_t hi = (uint16_t)uart_getc_blocking();
        fb16[i] = (uint16_t)(lo | (hi << 8));
    }

    return 1;
}

int main(void) {
    HDMI_ENABLE  = 1u;
    FB_BASE_WORD = FB_WORD_OFFSET;
    led_set(0u);

    fill_solid_rgb565(0x001F); // blue = boot OK / waiting for image

    while (1) {
        if ((UART_STATUS & UART_OVERRUN_MASK) != 0u) {
            uart_clear_overrun();
            fill_solid_rgb565(0xF800); // red = UART overrun / debug
            led_set(2u);
        }

        if (receive_image_packet()) {
            HDMI_ENABLE  = 1u;
            FB_BASE_WORD = FB_WORD_OFFSET;
            led_set(1u); // image received OK
        } else {
            fill_solid_rgb565(0xFFE0); // yellow = bad header/size packet
            led_set(3u);
        }
    }

    return 0;
}
