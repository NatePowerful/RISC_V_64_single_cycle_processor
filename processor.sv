module rv64_processor (
    input logic clk,
    input logic rst_n
);

    logic [63:0] pc;
    logic [63:0] pc_next;
    logic [63:0] pc_add_4;

    // PC + 4 (instructions are 4 bytes in RISC-V)
    assign pc_add_4 = pc + 64'd4;

    // For now, next PC is always PC + 4 (no branches/jumps yet)
    assign pc_next = pc_add_4;

    // Program counter
    program_counter pc1 (
        .clk     (clk),
        .resetn  (resetn),
        .pc_next (pc_next),
        .pc_prev (pc)
    );

    data_memory data_mem (
        .clk (clk),
        .rst_n (rst_n),
        .addr (addr),
        .write_data (write_data),
        .write_en (write_en),
        .read_en (read_en),
        .read_data (read_data)
    );

    
endmodule