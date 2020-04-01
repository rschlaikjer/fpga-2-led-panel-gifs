#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <stdlib.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <Vflash_loader.h>

struct DummyFlash {
  DummyFlash(uint8_t *mosi, uint8_t *miso, uint8_t *sck, uint8_t *cs)
      : spi_mosi(mosi), spi_miso(miso), spi_sck(sck), spi_cs(cs) {}

  uint8_t *spi_mosi;
  uint8_t *spi_miso;
  uint8_t *spi_sck;
  uint8_t *spi_cs;

  const uint8_t *data =
      reinterpret_cast<const uint8_t *>("This is a test string");

  // Current shift register output index
  unsigned shift_bit_index = 0;
  unsigned shift_byte_index = 0;
  unsigned preamble_bit_count = 0;

  // Last clock state
  uint8_t last_sck = 0;
  uint8_t last_cs = 0;

  void eval() {
    // Did the CS state change
    if (*spi_cs != last_cs) {
      fprintf(stderr, "CS state: was %u, now %u\n", last_cs, *spi_cs);
      if (*spi_cs == 0) {
        // Reset preamble counter so we don't respond during the read command
        // setup
        preamble_bit_count = 0;
        shift_byte_index = 0;
        shift_bit_index = 0;
        *spi_miso = 1;
        last_sck = *spi_sck;
      } else {
        // Deselect
        *spi_miso = 1;
      }
      last_cs = *spi_cs;
    }

    // Are we currently selected?
    if (last_cs == 0) {
      // Did the clock transition?
      if (*spi_sck != last_sck) {
        last_sck = *spi_sck;
        if (last_sck) {
          // Posedge
          preamble_bit_count++;
        } else {
          // Negedge
          // Don't shift data if this is the read preamble
          if (preamble_bit_count >= 40) {
            // Set miso to be the next bit
            *spi_miso =
                data[shift_byte_index] & (0b1000'0000 >> shift_bit_index) ? 1
                                                                          : 0;
            // Increment the bit index
            shift_bit_index++;
            // If we hit the end of the byte, increment the byte index
            if (shift_bit_index > 7) {
              shift_bit_index = 0;
              shift_byte_index++;
              fprintf(stderr, "New byte: %02x\n", data[shift_byte_index]);
            }
          }
        }
      }
    }
  }
};

int main(int argc, char **argv) {
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  // Create our trace output
  VerilatedVcdC *vcd_trace = new VerilatedVcdC();

  // Create an instance of our module under test
  Vflash_loader *flash_loader = new Vflash_loader;

  // Create a fake ADC connected to the master
  DummyFlash dummy_flash(&flash_loader->o_flash_mosi,
                         &flash_loader->i_flash_miso,
                         &flash_loader->o_flash_sck, &flash_loader->o_flash_cs);

  // Point the timer at the trace
  flash_loader->trace(vcd_trace, 99);

  vcd_trace->open("flash_loader.vcd");

  uint64_t trace_tick = 0;

  // Init to reset
  flash_loader->i_clk = 0;
  flash_loader->i_read_stb = 1;

  for (unsigned i = 0; i < 150000; i++) {
    // Negative edge
    flash_loader->i_clk = 0;
    flash_loader->eval();
    dummy_flash.eval();
    vcd_trace->dump(trace_tick++);

    // Trigger read on clock 3;
    if (trace_tick == 3) {
      flash_loader->i_read_stb = 1;
    } else {
      flash_loader->i_read_stb = 0;
    }

    // Posedge
    flash_loader->i_clk = 1;
    flash_loader->eval();
    dummy_flash.eval();
    vcd_trace->dump(trace_tick++);
  }

  vcd_trace->flush();
  vcd_trace->close();
  exit(EXIT_SUCCESS);
}
