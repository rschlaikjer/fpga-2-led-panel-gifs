// Memory layout is that each row is 64 16-bit words
// First word in row is rightmost pixel
// Bit 15 = red (top half), 14 = red (low half)

#include <stdint.h>
#include <stdio.h>

// Only top pixels are actually used atm
uint16_t pixels[64 * 64];

// Generate this pattern:
// R G R G
// G B G B
// R G R G
// G B G B

void set_pixel(int x, int y, bool r, bool g, bool b) {
  bool high_bank = y < 32;
  const unsigned index = (63 - x) + (y % 32) * 64;
  const uint16_t raw_val =
      (((r ? 1 : 0) << 4) | ((g ? 1 : 0) << 2) | ((b ? 1 : 0) << 0));
  const uint16_t val = high_bank ? raw_val << 11 : raw_val << 10;
  pixels[index] |= val;
}

int main() {
  // For this, x, y is top left
  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      int xm = x % 16;
      int ym = y % 16;
      if (xm < 8 && ym < 8) {
        // Red
        set_pixel(x, y, 1, 0, 0);
      }
      if (xm >= 8 && ym < 8) {
        // Green
        set_pixel(x, y, 0, 1, 0);
      }
      if (xm < 8 && ym >= 8) {
        // Green
        set_pixel(x, y, 0, 1, 0);
      }
      if (xm >= 8 && ym >= 8) {
        // Blue
        set_pixel(x, y, 0, 0, 1);
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
