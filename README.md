# FPGA-based animated GIF displayer

This repo contains the support materials for
[this blog post](https://rhye.org/post/fpgas-2-led-panel-display/)
that goes over building the gateware necessary to display animated GIFs on a
compatible RGB LED panel.

![Example Animation](/img/nyan_panel_muxed.gif)

The placement files in this repo assume that the project is running off of
[this HX4K breakout board](https://github.com/rschlaikjer/hx4k-pmod).

## Building the Gateware

To build the gateware, you will need the `yosys` + `nextpnr` toolchain.
Building the bitstream is the default target of the top-level Makefile.

In order to flash the bitstream to the board, if using the HX4K breakout you
will need the
[faff](https://github.com/rschlaikjer/faff)
tool,

## Simulations

In the `tb/` directory are two simulators that will exercise the panel driving
logic, as well as the flash reader. Both of these depend on
[Verilator](https://www.veripool.org/wiki/verilator).

## Image packer

To pack animations into a format that the FPGA can use, the `img_pack` tool in
`img_packer` can be used to convert multiple 64x64 images into a binary file
that can then be loaded into flash for display.
