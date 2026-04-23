// RV64 single-cycle processor top-level module.
// Connects all datapath and control components.
//
// Datapath signal flow per instruction:
//   IF:  PC -> instruction_memory -> instruction
//   ID:  instruction -> control (signals), immediate_gen (imm), registers (rs1/rs2)
//   EX:  alu_ctrl + mux(aluSrc) -> alu -> result, zero
//   MEM: alu_result -> data_memory (addr); write rs2 data or read into rd
//   WB:  mux(memToReg) -> register file write port (rd)
//   PC:  pcSrc = branch & zero -> mux(PC+4 or PC+imm) -> program_counter
module rv64_processor (
    input logic clk,   // clock: all sequential elements update on posedge
    input logic rst_n  // reset active-HIGH: rst_n=1 clears PC and memory
);

    // ---- PC stage ----
    logic [63:0] pc;          // current program counter (output of program_counter)
    logic [63:0] pc_next;     // next PC value (input to program_counter)
    logic [63:0] pc_plus4;    // PC + 4: sequential next instruction address
    logic [63:0] pc_branch;   // PC + imm: branch target address
    logic        pc_src;      // 0 = take PC+4, 1 = take PC+imm (branch taken)

    // ---- Instruction Fetch ----
    logic [31:0] instruction; // 32-bit instruction fetched from instruction_memory

    // ---- Control signals (from control.sv) ----
    logic        branch;      // 1 if instruction is BEQ/branch type
    logic        mem_write;   // 1 for SD: write to data memory
    logic        mem_read;    // 1 for LD: read from data memory
    logic        reg_write;   // 1 for R/I/LD: write result to register file
    logic [1:0]  alu_op_sel;  // ALU category for alu_ctrl (00/01/10)
    logic        mem_to_reg;  // 0=write ALU result, 1=write memory data to rd
    logic        alu_src;     // 0=op2 from rs2, 1=op2 from immediate

    // ---- Immediate ----
    logic [63:0] imm;         // 64-bit sign-extended immediate from immediate_gen

    // ---- Register file ----
    logic [63:0] rs1_data;    // value of register rs1 -> ALU op1
    logic [63:0] rs2_data;    // value of register rs2 -> ALU src mux / store data
    logic [63:0] rd_wdata;    // data to write back to rd (from wb_mux)

    // ---- ALU ----
    logic [3:0]  alu_op;      // exact ALU operation from alu_ctrl
    logic [63:0] alu_op2;     // ALU second operand after the src mux
    logic [63:0] alu_result;  // ALU output: memory address or computation result
    logic        zero;        // 1 when alu_result==0; used for BEQ branch decision

    // ---- Data memory ----
    logic [63:0] mem_rdata;   // 64-bit value loaded from data_memory (for LD)

    // ---- Branch / PC logic ----
    assign pc_src    = branch & zero; // branch taken only when branch=1 AND rs1==rs2
    assign pc_plus4  = pc + 64'd4;   // next sequential instruction
    assign pc_branch = pc + imm;      // branch target: current PC + sign-extended offset

    // =========================================================================
    // MODULE INSTANTIATIONS
    // =========================================================================

    // 1. Program Counter: register that holds the current PC.
    //    Updated on every posedge clk to pc_next.
    program_counter pc_reg (
        .clk     (clk),
        .rst_n   (rst_n),
        .pc_next (pc_next),  // input: computed next address
        .pc_prev (pc)        // output: current address used to fetch instruction
    );

    // 2. PC mux: chooses between sequential (PC+4) and branch target (PC+imm).
    //    sel=0 -> pc_plus4 (normal flow)
    //    sel=1 -> pc_branch (BEQ taken)
    mux_2_to_1 pc_mux (
        .op1 (pc_plus4),   // PC + 4
        .op2 (pc_branch),  // PC + imm
        .sel (pc_src),     // pcSrc = branch & zero
        .out (pc_next)     // feeds back into program_counter
    );

    // 3. Instruction memory: ROM containing the program.
    //    Combinational read: instruction is available the same cycle as addr.
    instruction_memory instr_mem (
        .clk         (clk),
        .rst_n       (rst_n),
        .addr        (pc),          // address = current PC
        .instruction (instruction)  // 32-bit instruction output
    );

    // 4. Control unit: decodes opcode[6:0] and drives all datapath signals.
    control ctrl (
        .opcode   (instruction[6:0]), // lower 7 bits identify instruction type
        .branch   (branch),
        .memWrite (mem_write),
        .memRead  (mem_read),
        .regWrite (reg_write),
        .aluOp    (alu_op_sel),
        .memToReg (mem_to_reg),
        .aluSrc   (alu_src)
    );

    // 5. Immediate generator: sign-extends the embedded immediate to 64 bits.
    immediate_gen imm_gen (
        .instruction (instruction),
        .immediate   (imm)
    );

    // 6. Register file: holds x0-x31 (each 64-bit).
    //    Two combinational reads, one clocked write.
    registers reg_file (
        .clk          (clk),
        .rst_n        (rst_n),
        .rs1_addr     (instruction[19:15]), // rs1 field of instruction
        .rs2_addr     (instruction[24:20]), // rs2 field of instruction
        .read_data1   (rs1_data),           // -> ALU op1
        .read_data2   (rs2_data),           // -> ALU src mux + store data
        .rd_addr      (instruction[11:7]),  // destination register
        .write_data   (rd_wdata),           // value to write back
        .write_enable (reg_write)           // from control
    );

    // 7. ALU source mux: selects between register rs2 and sign-extended immediate.
    //    sel=0 (aluSrc=0) -> R-type and BEQ use rs2
    //    sel=1 (aluSrc=1) -> I-type, LD, SD use the immediate
    mux_2_to_1 alu_src_mux (
        .op1 (rs2_data), // register rs2
        .op2 (imm),      // sign-extended immediate
        .sel (alu_src),  // 0=register, 1=immediate
        .out (alu_op2)   // -> ALU second operand
    );

    // 8. ALU control: maps (alu_op_sel + funct3/funct7) to a 4-bit alu_op code.
    alu_ctrl alu_control (
        .instruction (instruction),
        .alu_op_sel  (alu_op_sel),
        .alu_op      (alu_op)
    );

    // 9. ALU: performs the selected 64-bit operation.
    //    result -> memory address (LD/SD) or write-back value (R/I)
    //    zero   -> branch taken signal
    alu alu_unit (
        .op1     (rs1_data),  // always from rs1
        .op2     (alu_op2),   // rs2 or immediate (via mux)
        .alu_op  (alu_op),
        .result  (alu_result),
        .zero    (zero)
    );

    // 10. Data memory: 64-bit byte-addressable memory for LD/SD.
    //     Write: clocked, address=alu_result, data=rs2_data
    //     Read:  combinational, address=alu_result
    data_memory data_mem (
        .clk        (clk),
        .rst_n      (rst_n),
        .addr       (alu_result), // effective address computed by ALU
        .write_data (rs2_data),   // data to store (rs2 register value)
        .write_en   (mem_write),  // from control: 1 for SD
        .read_en    (mem_read),   // from control: 1 for LD
        .read_data  (mem_rdata)   // loaded value -> wb_mux
    );

    // 11. Write-back mux: selects what gets written to the destination register rd.
    //     sel=0 (memToReg=0) -> ALU result (R-type, I-type)
    //     sel=1 (memToReg=1) -> memory load data (LD)
    mux_2_to_1 wb_mux (
        .op1 (alu_result), // ALU computation result
        .op2 (mem_rdata),  // data loaded from memory
        .sel (mem_to_reg), // 0=ALU result, 1=memory data
        .out (rd_wdata)    // -> register file write port
    );

endmodule
