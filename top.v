`default_nettype none

`define CLK_HZ 48_000_000

module top(
        // Input clock
        input wire CLK_12MHZ,

        // RGB LEDs
        output wire LED_R,
        output wire LED_G,
        output wire LED_B,

        // Flash chip
        output wire FLASH_SPI_CS,
        output wire FLASH_SPI_SCK,
        output wire FLASH_SPI_MOSI,
        input  wire FLASH_SPI_MISO,

        // PMOD C1
        output wire PMOD_C1_D0,
        output wire PMOD_C1_D1,
        output wire PMOD_C1_D2,
        output wire PMOD_C1_D3,
        output wire PMOD_C1_D4,
        output wire PMOD_C1_D5,
        output wire PMOD_C1_D6,
        output wire PMOD_C1_D7,

        // PMOD C2
        output wire PMOD_C2_D0,
        output wire PMOD_C2_D1,
        output wire PMOD_C2_D2,
        output wire PMOD_C2_D3,
        output wire PMOD_C2_D4,
        output wire PMOD_C2_D5,
        output wire PMOD_C2_D6,
        output wire PMOD_C2_D7
    );

    // PLL
    wire clk_48mhz;
    wire pll_lock;
    ice_pll pll(CLK_12MHZ, clk_48mhz, pll_lock);

    // Reset handler
    reg reset = 1;
    reg [3:0] reset_counter = 4'hF;
    always @(posedge clk_48mhz) begin
        if (reset) begin
            if (reset_counter == 0)
                reset <= 0;
            else if (pll_lock)
                reset_counter <= reset_counter - 1;
        end
    end

    // Map those PMOD pins to some real signal names
    wire [1:0] rgb_panel_r = {PMOD_C1_D4, PMOD_C1_D0};
    wire [1:0] rgb_panel_g = {PMOD_C1_D5, PMOD_C1_D1};
    wire [1:0] rgb_panel_b = {PMOD_C1_D6, PMOD_C1_D2};
    wire [1:0] rgb_panel_x = {PMOD_C1_D7, PMOD_C1_D3};
    wire [4:0] rgb_panel_a = {PMOD_C2_D7,
                              PMOD_C2_D3,
                              PMOD_C2_D2,
                              PMOD_C2_D1,
                              PMOD_C2_D0};
    wire rgb_panel_bl = PMOD_C2_D4;
    wire rgb_panel_la = PMOD_C2_D5;
    wire rgb_panel_ck = PMOD_C2_D6;

    reg led = 0;
    assign LED_R = led;
    assign LED_B = ~led;

    reg flash_load_strobe;
    reg [7:0] frame_index = 0;

    localparam PRESCALER = (`CLK_HZ / 10) - 1;
    reg [$clog2(PRESCALER):0] prescaler_reg = 0;
    always @(posedge clk_48mhz) begin
        if (prescaler_reg == 0) begin
            led <= ~led;
            prescaler_reg <= PRESCALER;
            flash_load_strobe <= 1;
            if (frame_index == 11)
                frame_index <= 0;
            else
                frame_index <= frame_index + 1;
        end else begin
            // Downcount prescaler
            prescaler_reg <= prescaler_reg - 1;
            flash_load_strobe <= 0;
        end
    end

    wire [11:0] ram_w_addr;
    wire [15:0] ram_w_data;
    wire ram_write_stb;
    wire [10:0] ram_r_addr;
    wire [15:0] ram_bank1_data;
    wire [15:0] ram_bank2_data;
    wire ram_read_stb;
    pixel_ram ram1 (
        .i_clk(clk_48mhz),
        .i_w_data(ram_w_data),
        .i_w_addr(ram_w_addr),
        .i_w_enable(ram_write_stb),
        .i_r_addr(ram_r_addr),
        .o_bank1_data(ram_bank1_data),
        .o_bank2_data(ram_bank2_data),
        .i_r_enable(ram_read_stb)
    );

    localparam FLASH_BASE = 24'h80_00_00;
    wire [23:0] flash_load_addr = {FLASH_BASE[23:21], frame_index, 13'b0};
    // wire [23:0] flash_load_addr = FLASH_BASE;

    // Loader for initializing ram from the flash chip
    flash_loader loader(
        .i_clk(clk_48mhz),
        .i_read_addr(flash_load_addr),
        .i_read_stb(flash_load_strobe),
        // SPI lines
        .o_flash_mosi(FLASH_SPI_MOSI),
        .i_flash_miso(FLASH_SPI_MISO),
        .o_flash_sck(FLASH_SPI_SCK),
        .o_flash_cs(FLASH_SPI_CS),
        // Memory bus
        .o_ram_addr(ram_w_addr),
        .o_ram_data(ram_w_data),
        .o_ram_write_en(ram_write_stb)
    );

    panel_driver #(
        .PRESCALER(1)
    ) driver(
        .i_clk(clk_48mhz),
        // Memory interface
        .o_ram_addr(ram_r_addr),
        .i_ram_b1_data(ram_bank1_data),
        .i_ram_b2_data(ram_bank2_data),
        .o_ram_read_stb(ram_read_stb),
        .o_data_clock(rgb_panel_ck),
        .o_data_latch(rgb_panel_la),
        .o_data_blank(rgb_panel_bl),
        // Shift register data
        .o_data_r(rgb_panel_r),
        .o_data_g(rgb_panel_g),
        .o_data_b(rgb_panel_b),
        // Row select
        .o_row_select(rgb_panel_a)
    );

endmodule
