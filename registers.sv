// Register file for RV64 single-cycle processor.
// 32 x 64-bit registers (x0-x31).
// x0 is hardwired to 0: writes to x0 are ignored; reads always return 0.
// Two combinational read ports, one clocked write port.
module registers (
    input  logic        clk,           // clock: writes happen on rising edge
    input  logic        rst_n,         // reset active-HIGH: rst_n=1 clears all registers
    input  logic [4:0]  rs1_addr,      // read port 1 address (instruction[19:15])
    input  logic [4:0]  rs2_addr,      // read port 2 address (instruction[24:20])
    output logic [63:0] read_data1,    // data read from rs1 -> ALU op1
    output logic [63:0] read_data2,    // data read from rs2 -> ALU src mux / store data
    input  logic [4:0]  rd_addr,       // write port address  (instruction[11:7])
    input  logic [63:0] write_data,    // data to write (from wb_mux: ALU result or mem load)
    input  logic        write_enable   // 1=write this cycle (control.regWrite)
);

    logic [63:0] reg_file [0:31]; // 32 registers each 64 bits wide

    integer i;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            // reset: zero all registers (x0 stays 0; x1-x31 get a known starting state)
            for (i = 0; i < 32; i++) begin
                reg_file[i] <= 64'h0;
            end
        end else if (write_enable) begin
            // write-back: only write if destination is not x0 (x0 is hardwired to 0)
            if (rd_addr != 5'h0) begin
                reg_file[rd_addr] <= write_data; // non-blocking: new value visible next cycle
            end
        end
    end

    // Combinational reads: output is valid immediately, no clock edge needed.
    // Single-cycle design requires register values to be ready within the same cycle.
    assign read_data1 = reg_file[rs1_addr]; // rs1 -> ALU operand 1
    assign read_data2 = reg_file[rs2_addr]; // rs2 -> ALU src mux (op2) or store data

endmodule
