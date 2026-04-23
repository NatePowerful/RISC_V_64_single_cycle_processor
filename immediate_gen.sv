// Immediate generator for RV64 single-cycle processor.
// Extracts the immediate from the instruction and sign-extends it to 64 bits.
// Sign-extension replicates instruction[31] (sign bit) into the upper bits so
// negative offsets work correctly in 64-bit two's complement arithmetic.
module immediate_gen (
    input  logic [31:0] instruction, // full 32-bit instruction
    output logic [63:0] immediate    // 64-bit sign-extended immediate
);

    always_comb begin
        immediate = 64'h0; // default: R-type and unsupported opcodes have no immediate

        case (instruction[6:0]) // decode by opcode

            // I-type: imm[11:0] = instruction[31:20] (ADDI, ANDI, ORI, XORI)
            7'b0010011: immediate = {{52{instruction[31]}}, instruction[31:20]};

            // I-type load: same encoding as I-ALU (LD)
            7'b0000011: immediate = {{52{instruction[31]}}, instruction[31:20]};

            // S-type: imm split across two fields — upper 7 bits and lower 5 bits (SD)
            7'b0100011: immediate = {{52{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type: bits are interleaved in the encoding; imm[0]=0 (always even address) (BEQ)
            7'b1100011: immediate = {{51{instruction[31]}},
                                     instruction[31],    // imm[12] sign bit
                                     instruction[7],     // imm[11]
                                     instruction[30:25], // imm[10:5]
                                     instruction[11:8],  // imm[4:1]
                                     1'b0};              // imm[0] = 0
        endcase
    end

endmodule
