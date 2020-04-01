`default_nettype none

module pixel_ram(
    input wire i_clk,
    // Write interface
    input wire [11:0] i_w_addr,
    input wire [15:0] i_w_data,
    input wire i_w_enable,
    // Read interface
    input wire [10:0] i_r_addr,
    output reg [15:0] o_bank1_data,
    output reg [15:0] o_bank2_data,
    input wire i_r_enable
);

reg [15:0] data[4096];

always @(posedge i_clk)
    if (i_r_enable) begin
        o_bank1_data <= data[{1'b0, i_r_addr}];
        o_bank2_data <= data[{1'b1, i_r_addr}];
    end

always @(posedge i_clk)
    if (i_w_enable)
        data[i_w_addr] <= i_w_data;

endmodule
