// ALU for RV64 single-cycle processor.
// Performs the arithmetic/logical operation selected by alu_op.
// The zero flag is used by the branch logic: BEQ branches when zero=1.
//
// alu_op encoding (must match alu_ctrl.sv):
//   4'b0000 -> AND   4'b0001 -> OR
//   4'b0010 -> ADD   4'b0100 -> XOR
//   4'b0110 -> SUB   4'b0111 -> SLT (signed)
module alu (
    input  logic [63:0] op1,     // operand 1: always from register rs1
    input  logic [63:0] op2,     // operand 2: rs2 or sign-extended immediate (chosen by mux)
    input  logic [3:0]  alu_op,  // operation select from alu_ctrl
    output logic [63:0] result,  // 64-bit result -> memory address (LD/SD) or register write-back
    output logic        zero     // 1 when result==0; used by BEQ branch decision
);

    // zero is a continuous assignment: always mirrors result, no clock needed.
    // For BEQ: ALU computes rs1-rs2; if result==0 then rs1==rs2 -> branch taken.
    assign zero = (result == 64'h0);

    // Purely combinational: re-evaluates whenever op1, op2, or alu_op changes.
    always_comb begin
        case (alu_op)
            4'b0000: result = op1 & op2;   // AND  (R: AND/funct3=111, I: ANDI)
            4'b0001: result = op1 | op2;   // OR   (R: OR/funct3=110,  I: ORI)
            4'b0010: result = op1 + op2;   // ADD  (R: ADD, I: ADDI, also LD/SD address calc)
            4'b0100: result = op1 ^ op2;   // XOR  (R: XOR/funct3=100, I: XORI)
            4'b0110: result = op1 - op2;   // SUB  (R: SUB/funct7[5]=1, also BEQ comparison)
            4'b0111: result = ($signed(op1) < $signed(op2)) ? 64'h1 : 64'h0; // SLT signed
            default: result = 64'h0;       // undefined alu_op -> 0 (prevents latches)
        endcase
    end

endmodule
