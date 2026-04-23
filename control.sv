// Main control unit for RV64 single-cycle processor.
// Decodes the 7-bit opcode and produces all datapath control signals.
//
// Supported instructions and their opcodes:
//   R-type  (0110011): ADD, SUB, AND, OR, XOR, SLT
//   I-ALU   (0010011): ADDI, ANDI, ORI, XORI, SLTI
//   LD      (0000011): Load Doubleword (64-bit load)
//   SD      (0100011): Store Doubleword (64-bit store)
//   BEQ     (1100011): Branch if Equal
//
// Control signal summary:
//   aluSrc   : 0=use rs2,       1=use sign-extended immediate as ALU op2
//   memToReg : 0=write ALU result to rd, 1=write memory load data to rd
//   regWrite : 1=write to register file this cycle
//   memRead  : 1=data memory read enabled  (LD)
//   memWrite : 1=data memory write enabled (SD)
//   branch   : 1=this is a branch instruction; pcSrc = branch & zero
//   aluOp    : 2'b00=ADD(addr), 2'b01=SUB(branch), 2'b10=use funct3/funct7
module control (
    input  logic [6:0] opcode,   // instruction[6:0]: identifies instruction format
    output logic       branch,   // 1 for BEQ/BNE; drives pcSrc = branch & zero
    output logic       memWrite, // 1 for SD: enables clocked write to data_memory
    output logic       memRead,  // 1 for LD: gates combinational read from data_memory
    output logic       regWrite, // 1 for R/I/LD: enables write-back to register file
    output logic [1:0] aluOp,    // ALU category for alu_ctrl (00/01/10)
    output logic       memToReg, // 0=write ALU result, 1=write loaded memory data
    output logic       aluSrc    // 0=op2 from rs2, 1=op2 from sign-extended immediate
);

    always_comb begin
        // default all signals to 0 (safe NOP state; prevents latches in synthesis)
        branch   = 1'b0;
        memWrite = 1'b0;
        memRead  = 1'b0;
        regWrite = 1'b0;
        memToReg = 1'b0;
        aluSrc   = 1'b0;
        aluOp    = 2'b00;

        case (opcode)

            // ------------------------------------------------------------------
            // R-TYPE: ADD, SUB, AND, OR, XOR, SLT
            // Both operands are registers; result written back to rd.
            // alu_ctrl decodes funct3/funct7 to pick the exact operation.
            // ------------------------------------------------------------------
            7'b0110011: begin
                aluSrc   = 1'b0; // op2 = register rs2
                memToReg = 1'b0; // write ALU result to rd
                regWrite = 1'b1; // write result to register file
                memRead  = 1'b0; // no memory read
                memWrite = 1'b0; // no memory write
                branch   = 1'b0; // not a branch
                aluOp    = 2'b10; // tell alu_ctrl to use funct3/funct7
            end

            // ------------------------------------------------------------------
            // I-TYPE ALU: ADDI, ANDI, ORI, XORI, SLTI
            // Second operand is the 12-bit sign-extended immediate from the instruction.
            // ------------------------------------------------------------------
            7'b0010011: begin
                aluSrc   = 1'b1; // op2 = sign-extended immediate
                memToReg = 1'b0; // write ALU result to rd
                regWrite = 1'b1; // write result to register file
                memRead  = 1'b0;
                memWrite = 1'b0;
                branch   = 1'b0;
                aluOp    = 2'b10; // use funct3 (funct7[5] gated off for I-type in alu_ctrl)
            end

            // ------------------------------------------------------------------
            // LOAD DOUBLEWORD (LD)
            // ALU adds rs1 + imm to get the memory address.
            // The 64-bit value at that address is written to rd.
            // ------------------------------------------------------------------
            7'b0000011: begin
                aluSrc   = 1'b1; // op2 = immediate offset
                memToReg = 1'b1; // write MEMORY DATA (not ALU result) to rd
                regWrite = 1'b1; // write loaded value to register file
                memRead  = 1'b1; // enable data memory read
                memWrite = 1'b0;
                branch   = 1'b0;
                aluOp    = 2'b00; // ADD: effective_address = rs1 + imm
            end

            // ------------------------------------------------------------------
            // STORE DOUBLEWORD (SD)
            // ALU adds rs1 + imm to get the memory address.
            // rs2 is written to that address. No register write-back.
            // ------------------------------------------------------------------
            7'b0100011: begin
                aluSrc   = 1'b1; // op2 = immediate offset (split encoding, rebuilt by imm_gen)
                memToReg = 1'b0; // don't care (regWrite=0)
                regWrite = 1'b0; // SD does NOT write to the register file
                memRead  = 1'b0;
                memWrite = 1'b1; // enable data memory write
                branch   = 1'b0;
                aluOp    = 2'b00; // ADD: effective_address = rs1 + imm
            end

            // ------------------------------------------------------------------
            // BRANCH EQUAL (BEQ)
            // ALU subtracts rs1 - rs2 to test equality via the zero flag.
            // If zero=1: pc_next = PC + sign_ext(imm)  (branch taken)
            // If zero=0: pc_next = PC + 4               (not taken)
            // ------------------------------------------------------------------
            7'b1100011: begin
                aluSrc   = 1'b0; // op2 = register rs2 (compare two registers)
                memToReg = 1'b0; // don't care
                regWrite = 1'b0; // BEQ does NOT write to the register file
                memRead  = 1'b0;
                memWrite = 1'b0;
                branch   = 1'b1; // assert branch; pcSrc = branch & zero in processor
                aluOp    = 2'b01; // SUB: zero=1 iff rs1==rs2
            end

            // default: all signals stay 0 (set above) -> NOP behavior
        endcase
    end

endmodule
