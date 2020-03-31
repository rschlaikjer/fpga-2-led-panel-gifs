`default_nettype none

module panel_driver(
    input wire i_clk,
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

localparam
    s_data_shift = 0,
    s_blank_set = 1,
    s_latch_set = 2,
    s_increment_row = 3,
    s_latch_clear = 4,
    s_blank_clear = 5;

    // Register some outputs
    reg data_clock = 0;
    reg data_latch = 0;
    reg data_blank = 1;
    reg [4:0] row_address;
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

    reg [2:0] state = s_data_shift;
    reg [7:0] pixels_to_shift = 128;
    always @(posedge i_clk) begin
        case (state)
            s_data_shift: begin
             // Shift out new column data for this row
             if (pixels_to_shift > 0) begin
                 if (data_clock == 0) begin
                     data_r <= 2'b10;
                     data_g <= 2'b01;
                     data_b <= 2'b00;
                     data_clock <= 1;
                 end else begin
                     data_clock <= 0;
                     pixels_to_shift <= pixels_to_shift - 1;
                 end
             end else begin
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
             state <= s_blank_clear;
         end
         s_latch_clear: begin
             // Clear the blanking line
             data_latch <= 0;
             state <= s_blank_clear;
         end
         s_blank_clear: begin
             // Clear the blanking line
             data_blank <= 0;

             // Move back to shift state, reset pixel counter
             pixels_to_shift <= 64;
             state <= s_data_shift;
         end
        endcase
    end

endmodule
