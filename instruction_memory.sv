// Instruction memory for RV64 single-cycle processor.
// Read-only during normal operation (no write port).
// Instructions are loaded into the memory on reset via always_ff.
// Read is combinational: instruction output is always valid for the current addr.
module instruction_memory (
    input  logic        clk,           // clock (write port uses posedge)
    input  logic        rst_n,         // reset, active-HIGH in this design
    input  logic [63:0] addr,          // byte address from the program counter
    output logic [31:0] instruction    // 32-bit fetched instruction (RISC-V is always 32-bit even in RV64)
);

    // 1 KB byte-addressable instruction memory (256 instructions x 4 bytes each)
    logic [7:0] mem [0:1023];

    integer i;

    // On reset, zero-fill memory then load sample program instructions.
    // Each 32-bit instruction is stored in LITTLE-ENDIAN byte order:
    //   lowest address = bits[7:0] (LSB), highest address = bits[31:24] (MSB).
    always_ff @(posedge clk) begin
        if (rst_n) begin
            // clear all bytes to 0x00 first
            for (i = 0; i < 1024; i++) begin
                mem[i] <= 8'h00;
            end

            // --- sample program ---
            // PC=0 : ADDI x1, x0, 5   -> x1 = 5    (encoding: 0x00500093)
            mem[0]  <= 8'h93;  mem[1]  <= 8'h00;  mem[2]  <= 8'h50;  mem[3]  <= 8'h00;

            // PC=4 : ADDI x2, x0, 3   -> x2 = 3    (encoding: 0x00300113)
            mem[4]  <= 8'h13;  mem[5]  <= 8'h01;  mem[6]  <= 8'h30;  mem[7]  <= 8'h00;

            // PC=8 : ADD  x3, x1, x2  -> x3 = 8    (encoding: 0x002081B3)
            mem[8]  <= 8'hB3;  mem[9]  <= 8'h81;  mem[10] <= 8'h20;  mem[11] <= 8'h00;

            // PC=12: SD   x3, 0(x0)   -> mem[0]=8  (encoding: 0x00303023)
            mem[12] <= 8'h23;  mem[13] <= 8'h30;  mem[14] <= 8'h30;  mem[15] <= 8'h00;

            // PC=16: LD   x4, 0(x0)   -> x4 = 8    (encoding: 0x00003203)
            mem[16] <= 8'h03;  mem[17] <= 8'h32;  mem[18] <= 8'h00;  mem[19] <= 8'h00;

            // PC=20: BEQ  x1, x2, 8   -> no branch (x1!=x2), PC->24  (encoding: 0x00208463)
            mem[20] <= 8'h63;  mem[21] <= 8'h84;  mem[22] <= 8'h20;  mem[23] <= 8'h00;
        end
    end

    // Combinational read: reassemble 4 bytes into one 32-bit instruction.
    // addr[9:0] truncates the 64-bit PC to a 10-bit index (0..1023).
    // Little-endian reassembly: MSB byte is at the highest address.
    assign instruction = {mem[addr[9:0]+3], mem[addr[9:0]+2], mem[addr[9:0]+1], mem[addr[9:0]]};

endmodule
