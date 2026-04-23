// ALU control unit for RV64 single-cycle processor.
// Two-level decode: control.sv decodes the FORMAT (load/store/branch/ALU),
// this module decodes the specific OPERATION within that format using funct3/funct7.
//
// alu_op_sel truth table:
//   2'b00 -> ADD  (load/store: effective address = rs1 + imm)
//   2'b01 -> SUB  (branch: zero=1 iff rs1==rs2)
//   2'b10 -> consult funct3 (and funct7[5] for R-type ADD vs SUB)
module alu_ctrl (
    input  logic [31:0] instruction, // full instruction (funct3=bits[14:12], funct7[5]=bit[30])
    input  logic [1:0]  alu_op_sel,  // instruction category from control.sv
    output logic [3:0]  alu_op       // operation select to ALU
);

    wire [2:0] funct3;
    wire       funct7_5;

    assign funct3   = instruction[14:12]; // identifies operation within a type (e.g. 000=ADD, 111=AND)
    // Gate funct7[5] with instruction[5] (opcode[5]):
    //   opcode[5]=1 for R-type (0110011) so funct7[5] is valid there.
    //   opcode[5]=0 for I-type (0010011) so instruction[30] is part of the immediate, not funct7.
    //   Without this gate, ADDI with a large immediate could wrongly decode as SUB.
    assign funct7_5 = instruction[30] & instruction[5];

    always_comb begin
        case (alu_op_sel)
            2'b00: alu_op = 4'b0010;  // load/store -> always ADD for address calculation
            2'b01: alu_op = 4'b0110;  // branch     -> always SUB for equality comparison
            2'b10: begin               // R-type or I-type ALU: use funct3 to select
                case (funct3)
                    3'b000: alu_op = funct7_5 ? 4'b0110 : 4'b0010; // SUB (R) or ADD (R/ADDI)
                    3'b111: alu_op = 4'b0000;  // AND / ANDI
                    3'b110: alu_op = 4'b0001;  // OR  / ORI
                    3'b100: alu_op = 4'b0100;  // XOR / XORI
                    3'b010: alu_op = 4'b0111;  // SLT / SLTI (signed less-than)
                    default: alu_op = 4'b0010; // default to ADD
                endcase
            end
            default: alu_op = 4'b0010; // safe default
        endcase
    end

endmodule
