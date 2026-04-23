// Testbench for rv64_processor.
// Drives clock and reset, runs the 6-instruction sample program loaded in
// instruction_memory, then checks register and memory results.
//
// Sample program (loaded in instruction_memory.sv at reset):
//   PC= 0: ADDI x1, x0, 5   -> x1 = 5
//   PC= 4: ADDI x2, x0, 3   -> x2 = 3
//   PC= 8: ADD  x3, x1, x2  -> x3 = 8
//   PC=12: SD   x3, 0(x0)   -> data_mem[0] = 8
//   PC=16: LD   x4, 0(x0)   -> x4 = 8
//   PC=20: BEQ  x1, x2, 8   -> x1!=x2, no branch, PC -> 24
`timescale 1ns/1ps

module tb_processor;

    logic clk;   // processor clock
    logic rst_n; // reset (active-HIGH in this design: rst_n=1 asserts reset)

    // Instantiate the device under test
    rv64_processor dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // Clock generation: 10 ns period (100 MHz)
    // Starts LOW, toggles every 5 ns on its own.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Task to check a register value and print PASS or FAIL
    task check_reg;
        input [4:0]  reg_num;   // register index (0-31)
        input [63:0] expected;  // expected 64-bit value
        input [63:0] actual;    // actual value from hierarchical reference
        begin
            if (actual === expected)
                $display("PASS: x%0d = %0d (0x%016X)", reg_num, expected, expected);
            else
                $display("FAIL: x%0d = %0d (0x%016X), expected %0d (0x%016X)",
                         reg_num, actual, actual, expected, expected);
        end
    endtask

    // Main test sequence
    initial begin
        // Dump waveforms for GTKWave or similar viewer
        $dumpfile("tb_processor.vcd");
        $dumpvars(0, tb_processor);

        // ---- Apply Reset ----
        // Hold reset for two clock cycles so instruction_memory and
        // data_memory both initialize their arrays.
        rst_n = 1'b1;           // assert reset (active-HIGH)
        @(posedge clk);         // wait one rising edge
        @(posedge clk);         // wait one more for safety
        rst_n = 1'b0;           // release reset -> processor begins executing

        // ---- Let the program run ----
        // 6 instructions x 1 cycle each = 6 cycles minimum.
        // Wait 10 cycles to be safe (extra cycles run NOPs from zeroed memory).
        repeat (10) @(posedge clk);
        #1; // small delay after last posedge so registers have settled

        // ---- Check results ----
        $display("-------- Register Check --------");
        check_reg(1, 64'd5,  dut.reg_file.reg_file[1]);  // ADDI x1=5
        check_reg(2, 64'd3,  dut.reg_file.reg_file[2]);  // ADDI x2=3
        check_reg(3, 64'd8,  dut.reg_file.reg_file[3]);  // ADD  x3=8
        check_reg(4, 64'd8,  dut.reg_file.reg_file[4]);  // LD   x4=8

        $display("-------- Memory Check ----------");
        // SD stored 8 (0x0000_0000_0000_0008) at address 0 (little-endian)
        if (dut.data_mem.mem[0] === 8'h08)
            $display("PASS: data_mem[0] = 0x08 (LSB of value 8)");
        else
            $display("FAIL: data_mem[0] = 0x%02X, expected 0x08", dut.data_mem.mem[0]);

        $display("-------- PC Check --------------");
        // After BEQ (x1!=x2 so no branch), PC should be 24
        if (dut.pc === 64'd24)
            $display("PASS: PC = 24 (BEQ not taken, sequential flow)");
        else
            $display("FAIL: PC = %0d, expected 24", dut.pc);

        $display("--------------------------------");
        $finish; // end simulation
    end

    // Optional: print register state and PC every cycle for debugging
    always @(posedge clk) begin
        if (!rst_n)
            $display("t=%0t | PC=%0d | instr=0x%08X | x1=%0d x2=%0d x3=%0d x4=%0d",
                     $time, dut.pc, dut.instruction,
                     dut.reg_file.reg_file[1], dut.reg_file.reg_file[2],
                     dut.reg_file.reg_file[3], dut.reg_file.reg_file[4]);
    end

endmodule
