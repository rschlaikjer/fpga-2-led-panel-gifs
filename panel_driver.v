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
    s_blank_clear = 5;

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
                         data_r <= {i_ram_b2_data[15], i_ram_b1_data[15]};
                         data_g <= {i_ram_b2_data[10], i_ram_b1_data[10]};
                         data_b <= {i_ram_b2_data[4], i_ram_b1_data[4]};
                         // data_r <= i_ram_data[15:12];
                         // data_g <= i_ram_data[11:6];
                         // data_b <= i_ram_data[4:0];
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

                 // Reset number of pixels to shift
                 pixels_to_shift <= 64;

                 // Set the read strobe high here so the first cycle of the shift
                 // stage has valid data
                 ram_read_stb <= 1;
                 state <= s_data_shift;
             end
            endcase
        end
    end

endmodule
