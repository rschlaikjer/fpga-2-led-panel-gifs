#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <stdlib.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <Vpanel_driver.h>

uint16_t display_ram[256];

int main(int argc, char **argv) {
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  // Create our trace output
  VerilatedVcdC *vcd_trace = new VerilatedVcdC();

  // Create an instance of our module under test
  Vpanel_driver *panel_driver = new Vpanel_driver;

  // Point the timer at the trace
  panel_driver->trace(vcd_trace, 99);

  vcd_trace->open("panel_driver.vcd");

  uint64_t trace_tick = 0;

  for (int i = 0; i < 256; i++) {
    display_ram[i] = i;
  }

  for (unsigned i = 0; i < 150000; i++) {
    // Negative edge
    panel_driver->i_clk = 0;
    panel_driver->eval();
    vcd_trace->dump(trace_tick++);

    // Set up the display ram read
    panel_driver->i_ram_b1_data = display_ram[panel_driver->o_ram_addr];
    panel_driver->i_ram_b2_data = display_ram[panel_driver->o_ram_addr + 128];

    // Posedge
    panel_driver->i_clk = 1;
    panel_driver->eval();
    vcd_trace->dump(trace_tick++);
  }

  vcd_trace->flush();
  vcd_trace->close();
  exit(EXIT_SUCCESS);
}
