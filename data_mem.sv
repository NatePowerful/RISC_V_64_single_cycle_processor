// Data memory for RV64 single-cycle processor.
// Byte-addressable, 1 KB (indices 0-1023).
// Supports 64-bit (doubleword) reads and writes in little-endian byte order:
//   least-significant byte stored at the lowest address.
// Writes are clocked (posedge clk, when write_en=1).
// Reads are combinational (read_data is always valid given addr and read_en).
module data_memory (
    input  logic        clk,         // clock: writes commit on rising edge
    input  logic        rst_n,       // reset active-HIGH: rst_n=1 initializes memory
    input  logic [63:0] addr,        // byte address (computed by ALU: rs1 + imm_offset)
    input  logic [63:0] write_data,  // 64-bit value from rs2 to store (SD instruction)
    input  logic        write_en,    // 1=write this cycle (control.memWrite, asserted for SD)
    input  logic        read_en,     // 1=read is valid   (control.memRead,  asserted for LD)
    output logic [63:0] read_data    // 64-bit value loaded from memory (goes to wb_mux for LD)
);

    logic [7:0] mem [0:1023]; // 1024 bytes of data memory

    integer i;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            // reset: zero all bytes, then pre-load a known test value at address 0
            for (i = 0; i < 1024; i++) begin
                mem[i] <= 8'h00;
            end
            // pre-load address 0 with value 5 (little-endian 64-bit)
            mem[0] <= 8'h05;  // bits[7:0]   (LSB at lowest address)
            mem[1] <= 8'h00;  mem[2] <= 8'h00;  mem[3] <= 8'h00;
            mem[4] <= 8'h00;  mem[5] <= 8'h00;  mem[6] <= 8'h00;
            mem[7] <= 8'h00;  // bits[63:56] (MSB at highest address)
        end else begin
            if (write_en) begin
                // SD: write 8 bytes starting at addr, least-significant byte first
                mem[addr[9:0]]   <= write_data[7:0];   // byte 0 (LSB) at lowest address
                mem[addr[9:0]+1] <= write_data[15:8];
                mem[addr[9:0]+2] <= write_data[23:16];
                mem[addr[9:0]+3] <= write_data[31:24];
                mem[addr[9:0]+4] <= write_data[39:32];
                mem[addr[9:0]+5] <= write_data[47:40];
                mem[addr[9:0]+6] <= write_data[55:48];
                mem[addr[9:0]+7] <= write_data[63:56]; // byte 7 (MSB) at highest address
            end
        end
    end

    // Combinational read: reassemble 8 bytes back into 64-bit doubleword (little-endian).
    // read_en gates the output: when 0, output is 0 so stale data can't reach the register file.
    assign read_data = read_en
        ? {mem[addr[9:0]+7], mem[addr[9:0]+6], mem[addr[9:0]+5], mem[addr[9:0]+4],
           mem[addr[9:0]+3], mem[addr[9:0]+2], mem[addr[9:0]+1], mem[addr[9:0]]}
        : 64'h0;

endmodule
