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

            // PC=24: SUB  x5, x3, x2  -> x5 = 8-3 = 5    (encoding: 0x402182B3)
            mem[24] <= 8'hB3;  mem[25] <= 8'h82;  mem[26] <= 8'h21;  mem[27] <= 8'h40;

            // PC=28: AND  x6, x1, x2  -> x6 = 5&3 = 1    (encoding: 0x0020F333)
            mem[28] <= 8'h33;  mem[29] <= 8'hF3;  mem[30] <= 8'h20;  mem[31] <= 8'h00;

            // PC=32: OR   x7, x1, x2  -> x7 = 5|3 = 7    (encoding: 0x0020E3B3)
            mem[32] <= 8'hB3;  mem[33] <= 8'hE3;  mem[34] <= 8'h20;  mem[35] <= 8'h00;

            // PC=36: ADDI x8, x0, -1  -> x8 = -1 (0xFFFF...FFFF)  (encoding: 0xFFF00413)
            mem[36] <= 8'h13;  mem[37] <= 8'h04;  mem[38] <= 8'hF0;  mem[39] <= 8'hFF;

            // PC=40: ADDI x10, x0, 4  -> x10 = 4 (setup for BEQ-taken test)  (encoding: 0x00400513)
            mem[40] <= 8'h13;  mem[41] <= 8'h05;  mem[42] <= 8'h40;  mem[43] <= 8'h00;

            // PC=44: ADDI x11, x0, 4  -> x11 = 4 (setup for BEQ-taken test)  (encoding: 0x00400593)
            mem[44] <= 8'h93;  mem[45] <= 8'h05;  mem[46] <= 8'h40;  mem[47] <= 8'h00;

            // PC=48: BEQ  x10, x11, 8 -> branch TAKEN (4==4), PC->56 (encoding: 0x00B50463)
            mem[48] <= 8'h63;  mem[49] <= 8'h04;  mem[50] <= 8'hB5;  mem[51] <= 8'h00;

            // PC=52: ADDI x12, x0, 99 -> SKIPPED if branch taken  (encoding: 0x06300613)
            //   If x12==0 after simulation, branch was taken correctly.
            //   If x12==99, branch failed and this instruction ran.
            mem[52] <= 8'h13;  mem[53] <= 8'h06;  mem[54] <= 8'h30;  mem[55] <= 8'h06;

            // PC=56: NOP (ADDI x0,x0,0) -> landed here after branch  (encoding: 0x00000013)
            mem[56] <= 8'h13;  mem[57] <= 8'h00;  mem[58] <= 8'h00;  mem[59] <= 8'h00;

            // PC=60: ADDI x0, x0, 5  -> x0 hardwired-zero test; write must be ignored  (encoding: 0x00500013)
            mem[60] <= 8'h13;  mem[61] <= 8'h00;  mem[62] <= 8'h50;  mem[63] <= 8'h00;
        end
    end

    // Combinational read: reassemble 4 bytes into one 32-bit instruction.
    // addr[9:0] truncates the 64-bit PC to a 10-bit index (0..1023).
    // Little-endian reassembly: MSB byte is at the highest address.
    assign instruction = {mem[addr[9:0]+3], mem[addr[9:0]+2], mem[addr[9:0]+1], mem[addr[9:0]]};

endmodule
