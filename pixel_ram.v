`default_nettype none

module pixel_ram(
    input wire i_clk,
    // Write interface
    input wire [11:0] i_w_addr,
    input wire [15:0] i_w_data,
    input wire i_w_enable,
    // Read interface
    input wire [11:0] i_r_addr,
    output reg [15:0] o_r_data,
    input wire i_r_enable
);

reg [15:0] data[4096];
// integer i;
initial begin
    // data[0] = 16'b10_00_00_00_00000000;
    // for (i = 1; i < 4096; i++)
    //     data[i] = 16'h0000;
    $readmemh("image.hex", data);
end

always @(posedge i_clk)
    if (i_r_enable)
        o_r_data <= data[i_r_addr];

always @(posedge i_clk)
    if (i_w_enable)
        data[i_w_addr] <= i_w_data;

    /*

wire [15:0] ram_data [15:0];
wire [15:0] ram_select;

// Mux output data based on which block is being addressed
assign o_r_data = ram_data[i_r_addr[11:8]];

// Select chips based on high 4 address bits
assign ram_select = demux(i_w_addr[11:8]);

function [15:0] demux(input [3:0] addr);
    case (addr)
        4'h0 : demux = 16'b0000_0000_0000_0001;
        4'h1 : demux = 16'b0000_0000_0000_0010;
        4'h2 : demux = 16'b0000_0000_0000_0100;
        4'h3 : demux = 16'b0000_0000_0000_1000;
        4'h4 : demux = 16'b0000_0000_0001_0000;
        4'h5 : demux = 16'b0000_0000_0010_0000;
        4'h6 : demux = 16'b0000_0000_0100_0000;
        4'h7 : demux = 16'b0000_0000_1000_0000;
        4'h8 : demux = 16'b0000_0001_0000_0000;
        4'h9 : demux = 16'b0000_0010_0000_0000;
        4'hA : demux = 16'b0000_0100_0000_0000;
        4'hB : demux = 16'b0000_1000_0000_0000;
        4'hC : demux = 16'b0001_0000_0000_0000;
        4'hD : demux = 16'b0010_0000_0000_0000;
        4'hE : demux = 16'b0100_0000_0000_0000;
        4'hF : demux = 16'b1000_0000_0000_0000;
    endcase
endfunction

genvar i;
generate for (i = 0; i < 16; i = i + 1)
    pixel_ram_block ram(
        .i_clk(i_clk),
        .i_w_addr(i_w_addr[7:0]),
        .i_w_data(i_w_data),
        .i_w_enable(ram_select[i] && i_w_enable),
        .i_r_addr(i_r_addr[7:0]),
        .o_r_data(ram_data[i]),
        .i_r_enable(ram_select[i] && i_r_enable)
    );
endgenerate


*/

endmodule
