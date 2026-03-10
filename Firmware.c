#include <stdint.h>

#define PERIPH_BASE      0xF0000000u

#define HDMI_ENABLE      (*(volatile uint32_t*)(PERIPH_BASE + 0x00))
#define FB_BASE_WORD     (*(volatile uint32_t*)(PERIPH_BASE + 0x04))
#define REG_STATUS       (*(volatile uint32_t*)(PERIPH_BASE + 0x08))
#define LED_CTRL         (*(volatile uint32_t*)(PERIPH_BASE + 0x0C))
#define UART_DATA        (*(volatile uint32_t*)(PERIPH_BASE + 0x10))
#define UART_STATUS      (*(volatile uint32_t*)(PERIPH_BASE + 0x14))

#define RAM_BASE         0x40000000u
#define FB_WORD          ((volatile uint32_t*)RAM_BASE)
#define FB_HALF          ((volatile uint16_t*)RAM_BASE)

#define FB_WIDTH         300u
#define FB_HEIGHT        300u
#define FB_PIXELS        (FB_WIDTH * FB_HEIGHT)

static uint8_t uart_getc(void) {
    while ((UART_STATUS & 1u) == 0u) {
    }
    return (uint8_t)(UART_DATA & 0xFFu);
}

static uint16_t uart_get_u16(void) {
    uint16_t lo = uart_getc();
    uint16_t hi = uart_getc();
    return (uint16_t)(lo | (hi << 8));
}

static void fill_color(uint16_t color) {
    uint32_t i;
    for (i = 0; i < FB_PIXELS; i++) {
        FB_HALF[i] = color;
    }
}

static void fill_checkerboard(void) {
    uint32_t x, y;
    for (y = 0; y < FB_HEIGHT; y++) {
        for (x = 0; x < FB_WIDTH; x++) {
            if (((x >> 4) ^ (y >> 4)) & 1u) {
                FB_HALF[y * FB_WIDTH + x] = 0xFFFF; // trắng
            } else {
                FB_HALF[y * FB_WIDTH + x] = 0x0000; // đen
            }
        }
    }
}

static int recv_image_to_fb(void) {
    uint8_t h0, h1, h2, h3;
    uint16_t width, height;
    uint32_t total_pixels;
    uint32_t i, widx;
    uint32_t p0, p1;

    h0 = uart_getc();
    h1 = uart_getc();
    h2 = uart_getc();
    h3 = uart_getc();

    if (h0 != 'I' || h1 != 'M' || h2 != 'G' || h3 != '1') {
        return 0;
    }

    width  = uart_get_u16();
    height = uart_get_u16();

    if (width != FB_WIDTH || height != FB_HEIGHT) {
        return 0;
    }

    total_pixels = (uint32_t)width * (uint32_t)height;
    widx = 0;

    for (i = 0; i < total_pixels; i += 2) {
        p0 = uart_get_u16();
        if (i + 1u < total_pixels) {
            p1 = uart_get_u16();
        } else {
            p1 = 0;
        }

        FB_WORD[widx++] = p0 | (p1 << 16);
    }

    return 1;
}

int main(void) {
    HDMI_ENABLE = 1u;
    FB_BASE_WORD = 0u;
    LED_CTRL = 0u;

    // Mặc định tô đỏ để biết hệ đang chạy
    fill_color(0xF800);

    // Muốn test caro trắng/đen thì đổi sang:
    // fill_checkerboard();

    while (1) {
        if (recv_image_to_fb()) {
            LED_CTRL ^= 0x1u; 
        }
    }

    return 0;
}