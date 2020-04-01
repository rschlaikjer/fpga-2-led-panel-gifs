// Memory layout is that each row is 64 16-bit words
// First word in row is rightmost pixel
// Bit 15 = red (top half), 14 = red (low half)

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// Only top pixels are actually used atm

// Generate this pattern:
// R G R G
// G B G B
// R G R G
// G B G B

void set_pixel(uint16_t *pixels, int x, int y, bool r, bool g, bool b) {
  bool high_bank = y >= 32;
  const int index = (63 - x) + (y % 32) * 64;
  if (index < 0 || index >= 64 * 64)
    return;
  const uint16_t raw_val =
      (((r ? 1 : 0) << 4) | ((g ? 1 : 0) << 2) | ((b ? 1 : 0) << 0));
  const uint16_t val = high_bank ? raw_val << 11 : raw_val << 10;
  pixels[index] |= val;
}

void gen_bayer() {
  // For this, x, y is top left
  uint16_t pixels[64 * 64];
  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      int xm = x % 16;
      int ym = y % 16;
      if (xm < 8 && ym < 8) {
        // Red
        set_pixel(pixels, x, y, 1, 0, 0);
      }
      if (xm >= 8 && ym < 8) {
        // Green
        set_pixel(pixels, x, y, 0, 1, 0);
      }
      if (xm < 8 && ym >= 8) {
        // Green
        set_pixel(pixels, x, y, 0, 1, 0);
      }
      if (xm >= 8 && ym >= 8) {
        // Blue
        set_pixel(pixels, x, y, 0, 0, 1);
      }
    }
  }

  // Print em
  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      printf("%04x ", pixels[x + y * 64]);
    }

    printf("\n");
  }
}

void zero(uint16_t *buffer) { memset(buffer, 0, 64 * 64 * 2); }

void write_raw(uint16_t *pixels) {
  for (int i = 0; i < 64 * 64; i++) {
    putchar(pixels[i] >> 8);
    putchar(pixels[i] & 0xFF);
  }
}

void set_pixel_block(uint16_t *pixels, int x, int y, bool r, bool g, bool b) {
  set_pixel(pixels, x, y, r, g, b);

  set_pixel(pixels, x + 1, y, r, g, b);
  set_pixel(pixels, x - 1, y, r, g, b);

  set_pixel(pixels, x, y + 1, r, g, b);
  set_pixel(pixels, x, y - 1, r, g, b);

  set_pixel(pixels, x + 1, y - 1, r, g, b);
  set_pixel(pixels, x + 1, y + 1, r, g, b);
  set_pixel(pixels, x - 1, y - 1, r, g, b);
  set_pixel(pixels, x - 1, y + 1, r, g, b);
}

void gen_animation() {
  uint16_t pixels[64 * 64];
  for (int i = 0; i < 256; i++) {
    zero(pixels);

    // Draw three concentric cirle dots
    const float t_b = M_PI * 4 * ((float)i) / 256;
    const float t = sin(t_b);
    const float cost = cos(t);
    const float sint = sin(t);
    const int rb_x = cos(-t) * 5;
    const int rb_y = sin(-t) * 5;
    const int r_x = cos(t) * 10;
    const int r_y = sin(t) * 10;
    const int rg_x = cos(-t) * 15;
    const int rg_y = sin(-t) * 15;
    const int g_x = cos(t) * 20;
    const int g_y = sin(t) * 20;
    const int gb_x = cos(-t) * 25;
    const int gb_y = sin(-t) * 25;
    const int b_x = cos(t) * 30;
    const int b_y = sin(t) * 30;
    fprintf(stderr, " Red: %d, %d Grn: %d, %d Blu: %d, %d\n", r_x, r_y, g_x,
            g_y, b_x, b_y);

    set_pixel_block(pixels, 32, 32, 1, 1, 1);

    set_pixel_block(pixels, 32 + rb_x, 32 + rb_y, 1, 0, 1);
    set_pixel_block(pixels, 32 + r_x, 32 + r_y, 1, 0, 0);
    set_pixel_block(pixels, 32 + rg_x, 32 + rg_y, 1, 1, 0);
    set_pixel_block(pixels, 32 + g_x, 32 + g_y, 0, 1, 0);
    set_pixel_block(pixels, 32 + gb_x, 32 + gb_y, 0, 1, 1);
    set_pixel_block(pixels, 32 + b_x, 32 + b_y, 0, 0, 1);

    set_pixel_block(pixels, 32 - rb_x, 32 - rb_y, 1, 0, 1);
    set_pixel_block(pixels, 32 - r_x, 32 - r_y, 1, 0, 0);
    set_pixel_block(pixels, 32 - rg_x, 32 - rg_y, 1, 1, 0);
    set_pixel_block(pixels, 32 - g_x, 32 - g_y, 0, 1, 0);
    set_pixel_block(pixels, 32 - gb_x, 32 - gb_y, 0, 1, 1);
    set_pixel_block(pixels, 32 - b_x, 32 - b_y, 0, 0, 1);

    write_raw(pixels);
  }
}

int main() {
  // gen_bayer();
  gen_animation();
  return 0;
}
