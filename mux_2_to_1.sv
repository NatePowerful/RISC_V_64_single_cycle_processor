// 2-to-1 multiplexer, 64-bit wide.
// sel=0 selects op1, sel=1 selects op2.
// Used in three places in the datapath:
//   1. PC mux      : PC+4 (op1) vs PC+imm branch target (op2)   sel = pcSrc
//   2. ALU src mux : register rs2 (op1) vs sign-extended imm (op2)   sel = aluSrc
//   3. Write-back  : ALU result (op1) vs memory load data (op2)  sel = memToReg
module mux_2_to_1 (
    input  logic [63:0] op1, // selected when sel=0
    input  logic [63:0] op2, // selected when sel=1
    input  logic        sel, // select signal
    output logic [63:0] out  // output: op1 or op2
);

    assign out = sel ? op2 : op1; // ternary: if sel==1 output op2, else op1

endmodule
