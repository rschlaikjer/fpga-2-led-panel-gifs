`default_nettype none

`define CLK_HZ 48_000_000

module top(
        // Input clock
        input wire CLK_12MHZ,

        // RGB LEDs
        output wire LED_R,
        output wire LED_G,
        output wire LED_B,

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

    localparam PRESCALER = (`CLK_HZ / 128) - 1;
    reg [$clog2(PRESCALER):0] prescaler_reg = 0;
    always @(posedge clk_48mhz) begin
        if (prescaler_reg == 0) begin
            led <= ~led;
            prescaler_reg <= PRESCALER;
            ram_w_addr <= ram_w_addr + 1;
            ram_write_stb <= 1;
        end else begin
            ram_write_stb <= 0;
            if (ram_w_addr == 0) begin
                if (ram_w_data == 16'b11_00_00_00_00000000)
                    ram_w_data <= 16'b00_11_00_00_00000000;
                if (ram_w_data == 16'b00_11_00_00_00000000)
                    ram_w_data <= 16'b00_00_11_00_00000000;
                if (ram_w_data == 16'b00_00_11_00_00000000)
                    ram_w_data <= 16'b11_00_00_00_00000000;

            end
            // Downcount prescaler
            prescaler_reg <= prescaler_reg - 1;
        end
    end

    reg [11:0] ram_w_addr = 0;
    reg [15:0] ram_w_data = 16'h9000;
    wire ram_write_stb;
    wire [11:0] ram_r_addr;
    wire [15:0] ram_r_data;
    wire ram_read_stb;
    pixel_ram ram1 (
        .i_clk(clk_48mhz),
        .i_w_data(ram_w_data),
        .i_w_addr(ram_w_addr),
        .i_w_enable(ram_write_stb),
        .i_r_addr(ram_r_addr),
        .o_r_data(ram_r_data),
        .i_r_enable(ram_read_stb)
    );

    panel_driver driver(
        .i_clk(clk_48mhz),
        // Memory interface
        .o_ram_addr(ram_r_addr),
        .i_ram_data(ram_r_data),
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
