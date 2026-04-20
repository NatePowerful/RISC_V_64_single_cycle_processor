module registers(
    input logic clk, 
    input logic rst_n,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic [63:0] read_data1,
    input logic [63:0] read_data2,
    input logic [63:0] write_data,
    input logic write_enable
);

    logic [63:0] reg_file[0:31]; // 32 registers, each 64 bits wide

    integer i;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            for (i = 0; i < 32; i++) begin
                reg_file[i] <= 64'h0; // Clear registers on reset
            end 
        end else if (write_enable) begin
            if (rd_addr != 0) begin // Register x0 is hardwired to 0
                reg_file[rd_addr] <= write_data; // Write data to rd
            end
        end 
    end 
    assign read_data1 = reg_file[rs1_addr]; // Read data from rs1
    assign read_data2 = reg_file[rs2_addr]; // Read data from rs2

endmodule