`default_nettype none

module flash_loader(
        input wire i_clk,
        input wire [23:0] i_read_addr,
        input wire i_read_stb,
        // SPI connection to flash
        output wire o_flash_mosi,
        input  wire i_flash_miso,
        output wire o_flash_sck,
        output wire o_flash_cs,
        // Write interface to memory
        output wire [11:0] o_ram_addr,
        output wire [15:0] o_ram_data,
        output wire o_ram_write_en
    );

    // Instruction for initiating a read from the flash chip
    `define FLASH_OP_RESET    16'H6699
    `define FLASH_OP_FAST_READ 8'H0B
    `define FLASH_OP_WAKEUP    8'HAB


localparam
    s_idle = 0,
    s_initiate_reset = 1,
    s_initiate_wakeup = 2,
    s_initiate_read = 3,
    s_flush_command_buffer = 4,
    s_shift_data = 5;

    reg flash_sck = 0;
    reg flash_mosi = 0;
    reg flash_cs = 1;
    assign o_flash_sck = flash_sck;
    assign o_flash_mosi = flash_mosi;
    assign o_flash_cs = flash_cs;

    reg [3:0] state = s_idle;
    reg [3:0] next_state;
    reg [(8*5)-1:0] command_buffer;
    reg [5:0] cmd_buffer_bits_to_shift;

    reg [23:0] flash_read_addr;
    reg [15:0] input_shift_data = 0;
    reg [4:0] input_bits_to_shift = 0;
    reg [12:0] words_to_read = 0;

    reg [11:0] ram_address;
    reg [15:0] ram_data;
    reg ram_write_enable = 0;
    assign o_ram_addr = ram_address;
    assign o_ram_data = ram_data;
    assign o_ram_write_en = ram_write_enable;

    always @(posedge i_clk) begin
        case (state)
            s_idle: begin
                if (i_read_stb) begin
                    // To initiate a read, we need to clock out
                    // - The opcode
                    // - A 24 bit start address
                    // - One dummy clock
                    // And then the flash will read until we deassert CS.
                    flash_read_addr <= i_read_addr;
                    state <= s_initiate_reset;
                end
            end

            s_initiate_reset: begin
                command_buffer <= {`FLASH_OP_RESET, 24'b0};
                cmd_buffer_bits_to_shift <= 16;
                flash_cs <= 0;
                next_state <= s_initiate_wakeup;
                state <= s_flush_command_buffer;
            end

            s_initiate_wakeup: begin
                command_buffer <= {`FLASH_OP_WAKEUP, 32'b0};
                cmd_buffer_bits_to_shift <= 8;
                flash_cs <= 0;
                next_state <= s_initiate_read;
                state <= s_flush_command_buffer;
            end

            s_initiate_read: begin
                // Set the command to send
                command_buffer <= {`FLASH_OP_FAST_READ, flash_read_addr, 8'b0};
                cmd_buffer_bits_to_shift <= (5 * 8);
                flash_cs <= 0;

                // Also initialize the read data registers
                input_bits_to_shift <= 5'd16;
                words_to_read <= 4096;
                ram_address <= 0;

                // Process command buffer
                next_state <= s_shift_data;
                state <= s_flush_command_buffer;
            end

            s_flush_command_buffer: begin
                if (cmd_buffer_bits_to_shift > 0) begin
                    if (flash_sck == 0) begin
                        // Latch new data and perform rising edge
                        {flash_mosi, command_buffer} <= {command_buffer, 1'b0};
                        flash_sck <= 1;
                    end else begin
                        // Perform falling edge and decrement bit count
                        flash_sck <= 0;
                        cmd_buffer_bits_to_shift <= cmd_buffer_bits_to_shift - 1;
                    end
                end else begin
                    // Done - move to continuation state
                    state <= next_state;
                    // If we aren't moving to the read state, deassert CS
                    if (next_state != s_shift_data)
                        flash_cs <= 1;
                end
            end

            s_shift_data: begin
                // We are going to care about 16 bit chunks, since that's
                // the interface we're using for our block RAMs
                if (words_to_read == 0) begin
                    ram_write_enable <= 0;
                    flash_cs <= 1;
                    state <= s_idle;
                end else begin
                    if (input_bits_to_shift == 0) begin
                        // Done shifting a word, move it to the output data
                        // lines and strobe the write signal
                        ram_data <= input_shift_data;
                        ram_write_enable <= 1;
                        words_to_read <= words_to_read - 1;
                        input_bits_to_shift <= 16;
                    end else begin
                        // If we just did a write, bring the strobe back down
                        // and increment the write address for next time
                        if (ram_write_enable) begin
                            ram_write_enable <= 0;
                            ram_address <= ram_address + 1;
                        end
                        if (o_flash_sck == 0) begin
                            // Set up rising edge of SPI clock
                            flash_mosi <= 1'b0;
                            flash_sck <= 1;
                        end else begin
                            // Falling edge
                            flash_sck <= 0;
                            input_shift_data <= {input_shift_data[14:0], i_flash_miso};
                            input_bits_to_shift <= input_bits_to_shift - 1;
                        end
                    end
                end
            end
        endcase
    end

endmodule
