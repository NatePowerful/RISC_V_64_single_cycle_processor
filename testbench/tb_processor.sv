// Testbench for rv64_processor.
// Runs a 16-instruction program covering: ADDI, ADD, SD, LD,
// BEQ not-taken, SUB, AND, OR, negative immediate, BEQ taken, and x0 hardwired zero.
//
// Full program (in instruction_memory.sv):
//   PC= 0: ADDI x1,  x0,  5   -> x1 = 5
//   PC= 4: ADDI x2,  x0,  3   -> x2 = 3
//   PC= 8: ADD  x3,  x1,  x2  -> x3 = 8
//   PC=12: SD   x3,  0(x0)    -> mem[0] = 8
//   PC=16: LD   x4,  0(x0)    -> x4 = 8
//   PC=20: BEQ  x1,  x2,  8   -> NOT taken (5!=3), PC -> 24
//   PC=24: SUB  x5,  x3,  x2  -> x5 = 5   (8 - 3)
//   PC=28: AND  x6,  x1,  x2  -> x6 = 1   (5 & 3 = 0101 & 0011 = 0001)
//   PC=32: OR   x7,  x1,  x2  -> x7 = 7   (5 | 3 = 0101 | 0011 = 0111)
//   PC=36: ADDI x8,  x0, -1   -> x8 = 0xFFFFFFFFFFFFFFFF  (negative immediate)
//   PC=40: ADDI x10, x0,  4   -> x10 = 4
//   PC=44: ADDI x11, x0,  4   -> x11 = 4
//   PC=48: BEQ  x10, x11, 8   -> TAKEN (4==4), PC -> 56  (skips PC=52)
//   PC=52: ADDI x12, x0, 99   -> SKIPPED; x12 stays 0 proving branch was taken
//   PC=56: NOP  (ADDI x0,x0,0) -> lands here after branch
//   PC=60: ADDI x0,  x0,  5   -> x0 stays 0 (hardwired zero, write ignored)
`timescale 1ns/1ps

module tb_processor;

    logic clk;
    logic rst_n; // active-HIGH reset in this design

    rv64_processor dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // 10 ns clock period (100 MHz)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Helper task: compare actual vs expected and print PASS/FAIL
    task check_reg;
        input [4:0]  reg_num;
        input [63:0] expected;
        input [63:0] actual;
        begin
            if (actual === expected)
                $display("PASS: x%-2d = %0d", reg_num, expected);
            else
                $display("FAIL: x%-2d = %0d, expected %0d", reg_num, actual, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_processor.vcd"); // waveform output (open with GTKWave)
        $dumpvars(0, tb_processor);    // dump all signals in this scope

        // --- Reset ---
        // rst_n=1 asserts reset; hold for 2 cycles so always_ff memory initializes
        rst_n = 1'b1;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1'b0; // release reset, processor starts at PC=0

        // --- Run 15 instruction cycles ---
        // PC=0..44 = 12 sequential cycles, then BEQ taken skips PC=52,
        // landing at PC=56 (cycle 14), then PC=60 (cycle 15).
        repeat (15) @(posedge clk);
        #1; // wait 1 ps past the clock edge so all registers have updated

        // =====================================================================
        // CHECK RESULTS
        // =====================================================================

        $display("");
        $display("=== Basic ALU + Memory ===");
        check_reg( 1, 64'd5,  dut.reg_file.reg_file[1]);  // ADDI x1=5
        check_reg( 2, 64'd3,  dut.reg_file.reg_file[2]);  // ADDI x2=3
        check_reg( 3, 64'd8,  dut.reg_file.reg_file[3]);  // ADD  x3=8
        check_reg( 4, 64'd8,  dut.reg_file.reg_file[4]);  // LD   x4=8

        // data_mem[0] should hold 8 stored by SD (little-endian: LSB at lowest address)
        if (dut.data_mem.mem[0] === 8'h08)
            $display("PASS: data_mem[0] = 0x08  (SD stored 8 correctly)");
        else
            $display("FAIL: data_mem[0] = 0x%02X, expected 0x08", dut.data_mem.mem[0]);

        $display("");
        $display("=== BEQ Not-Taken (x1=5 != x2=3) ===");
        // Verified by the program continuing past PC=20 to execute PC=24 (SUB)
        check_reg(5, 64'd5, dut.reg_file.reg_file[5]);  // SUB ran => branch not taken

        $display("");
        $display("=== R-type Operations ===");
        check_reg( 5, 64'd5,  dut.reg_file.reg_file[5]);  // SUB  x5 = x3-x2 = 8-3 = 5
        check_reg( 6, 64'd1,  dut.reg_file.reg_file[6]);  // AND  x6 = x1&x2 = 5&3 = 1
        check_reg( 7, 64'd7,  dut.reg_file.reg_file[7]);  // OR   x7 = x1|x2 = 5|3 = 7

        $display("");
        $display("=== Negative Immediate (sign extension) ===");
        // ADDI x8, x0, -1 should sign-extend to 64'hFFFFFFFFFFFFFFFF
        check_reg(8, 64'hFFFFFFFFFFFFFFFF, dut.reg_file.reg_file[8]);

        $display("");
        $display("=== BEQ Taken (x10=4 == x11=4) ===");
        // BEQ at PC=48 branches to PC=56, skipping the ADDI x12=99 at PC=52.
        // x12 was never written, so it must still be 0.
        // If x12=99 the branch failed; if x12=0 the branch succeeded.
        check_reg(12, 64'd0, dut.reg_file.reg_file[12]);

        $display("");
        $display("=== x0 Hardwired Zero ===");
        // ADDI x0, x0, 5 at PC=60 should be silently ignored.
        check_reg(0, 64'd0, dut.reg_file.reg_file[0]);

        $display("");
        $finish;
    end

    // Per-cycle trace for debugging (only prints when not in reset)
    always @(posedge clk) begin
        if (!rst_n)
            $display("t=%6t | PC=%2d | instr=0x%08X | x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x6=%0d x7=%0d",
                     $time, dut.pc, dut.instruction,
                     dut.reg_file.reg_file[1], dut.reg_file.reg_file[2],
                     dut.reg_file.reg_file[3], dut.reg_file.reg_file[4],
                     dut.reg_file.reg_file[5], dut.reg_file.reg_file[6],
                     dut.reg_file.reg_file[7]);
    end

endmodule
