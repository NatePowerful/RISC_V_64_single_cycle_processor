module program_counter (
    input  logic        clk,
    input  logic        resetn,
    input  logic [63:0] pc_next,
    output logic [63:0] pc_prev
);

    always_ff @(posedge clk) begin
        if (!resetn) begin
            pc_prev <= 64'h0;
        end else begin
            pc_prev <= pc_next;
        end
    end

endmodule