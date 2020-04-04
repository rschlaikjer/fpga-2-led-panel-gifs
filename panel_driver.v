`default_nettype none

module panel_driver(
    input wire i_clk,
    // Memory interface
    output wire [10:0] o_ram_addr,
    input wire [15:0] i_ram_b1_data,
    input wire [15:0] i_ram_b2_data,
    output wire o_ram_read_stb,
    // Shift register control
    output wire o_data_clock,
    output wire o_data_latch,
    output wire o_data_blank,
    // Shift register data
    output wire [1:0] o_data_r,
    output wire [1:0] o_data_g,
    output wire [1:0] o_data_b,
    // Row select
    output wire [4:0] o_row_select
);

parameter PRESCALER = 0;

localparam
    s_data_shift = 0,
    s_blank_set = 1,
    s_latch_set = 2,
    s_increment_row = 3,
    s_latch_clear = 4,
    s_blank_clear = 5,
    s_expose_pixels = 6;

    // Register RAM signals
    reg [10:0] ram_addr = 0;
    reg ram_read_stb = 0;
    assign o_ram_addr = ram_addr;
    assign o_ram_read_stb = ram_read_stb;

    // Register some outputs
    reg data_clock = 0;
    reg data_latch = 0;
    reg data_blank = 1;
    reg [4:0] row_address = ~5'b0;
    reg [1:0] data_r = 0;
    reg [1:0] data_g = 0;
    reg [1:0] data_b = 0;

    // Wire up outputs
    assign o_data_clock = data_clock;
    assign o_data_latch = data_latch;
    assign o_data_blank = data_blank;
    assign o_row_select = row_address;
    assign o_data_r = data_r;
    assign o_data_g = data_g;
    assign o_data_b = data_b;

    // Since the panel might not be able to run at core clock speed,
    // add a prescaler to panel operations
    reg [$clog2(PRESCALER):0] prescaler_reg = 0;

    // In order to do better than 8 colours (R,G,B or combinations thereof)
    // we need to do some more complex multiplexing of the panel than just
    // scanning it once per update cycle. Instead, we want to display the
    // most significant bit of each colour twice as long as the next most
    // significant bit.
    // If we pack the image data about as densely as wel can, using the
    // RGB565 format (5 bits red, 6 bits green, five bits blue) we have
    // five bits of information for each colour. To dispalay each one twice
    // as long as the previous, we need the following number of time periods
    // per bit of information:
    // Bit 0: 1  (LSB)
    // Bit 1: 2
    // Bit 2: 4
    // Bit 3: 8
    // Bit 4: 16 (MSB).
    // In total, that's 31 time periods per update cycle if we want to display
    // colours with a 5 bit depth.

    // However, our panel is designed for 1/32 multiplexing - if we just leave
    // the exposure fully on for a given row, we will end up with an overexposed
    // image.

    // How many periods should we wait for the given bit of the pixel data
    // Bit 4 = MSB
    reg [8:0] time_periods_for_bit[5];
    initial begin
        time_periods_for_bit[4] = 64;
        time_periods_for_bit[3] = 32;
        time_periods_for_bit[2] = 16;
        time_periods_for_bit[1] = 8;
        time_periods_for_bit[0] = 4;
    end

    // How many time periods should we continue to wait for this bit of the
    // pixel data
    reg [8:0] time_periods_remaining;

    // Which bit of the pixel data are we currently displaying
    reg [2:0] pixel_bit_index = 4;

    reg [2:0] state = s_data_shift;
    reg [7:0] pixels_to_shift = 64;
    always @(posedge i_clk) begin
        if (prescaler_reg > 0)
            prescaler_reg <= prescaler_reg - 1;
        else begin
            prescaler_reg <= PRESCALER;
            case (state)
                s_data_shift: begin
                 // Shift out new column data for this row
                 // Need to load from internal RAM
                 if (pixels_to_shift > 0) begin
                     if (data_clock == 0) begin
                         // We need to load the n'th most significant bit of
                         // each colour channel, based on which pixel bit index
                         // we are currently displaying
                         // pixel_bit_index is in range 0..4
                         data_r <= {i_ram_b2_data[11 + pixel_bit_index],
                                    i_ram_b1_data[11 + pixel_bit_index]};
                         data_g <= {i_ram_b2_data[6 + pixel_bit_index],
                                    i_ram_b1_data[6 + pixel_bit_index]};
                         data_b <= {i_ram_b2_data[0 + pixel_bit_index],
                                    i_ram_b1_data[0 + pixel_bit_index]};
                         data_clock <= 1;
                         ram_addr <= ram_addr + 1;
                     end else begin
                         data_clock <= 0;
                         pixels_to_shift <= pixels_to_shift - 1;
                     end
                 end else begin
                    ram_read_stb <= 0;
                    state <= s_blank_set;
                 end
             end
             s_blank_set: begin
                 data_blank <= 1;
                 state <= s_latch_set;
             end
             s_latch_set: begin
                 data_latch <= 1;
                 state <= s_increment_row;
             end
             s_increment_row: begin
                 // Increment row
                 row_address <= row_address + 1;
                 state <= s_latch_clear;
             end
             s_latch_clear: begin
                 // Clear the blanking line
                 data_latch <= 0;
                 state <= s_blank_clear;
             end
             s_blank_clear: begin
                 // Clear the blanking line
                 data_blank <= 0;

                 // Load the number of time periods that we should expose this
                 // row for
                 time_periods_remaining <= time_periods_for_bit[pixel_bit_index];

                 // Move to the exposure state
                 state <= s_expose_pixels;
             end
             s_expose_pixels: begin
                 // Hold the row here for as many time periods as are required
                 // for the significance of the bit we are displaying
                 if (time_periods_remaining == 0) begin
                     // Reset number of pixels to shift
                     pixels_to_shift <= 64;
                     data_blank <= 1;

                     // Set the read strobe high here so the first cycle of the shift
                     // stage has valid data
                     ram_read_stb <= 1;

                     // If the current row address is zero, we have done one
                     // full scan through the display, and should move to the
                     // next most significant bit
                     if (row_address == 0) begin
                        if (pixel_bit_index == 0)
                            // If we hit the lsb, wrap to the msb
                            pixel_bit_index <= 4;
                        else
                            pixel_bit_index <= pixel_bit_index - 1;
                     end

                     // Advance back to the data shift state
                     state <= s_data_shift;
                end else begin
                    time_periods_remaining <= time_periods_remaining - 1;
                end
            end
            endcase
        end
    end

endmodule
