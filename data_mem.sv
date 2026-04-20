module data_memory (
    input logic clk,
    input logic rst_n,
    input logic [63:0] addr,
    input logic [63:0] write_data,
    input logic write_en,
    input logic read_en,
    output logic [63:0] read_data
);

    //
    logic [7:0] memmory[0:1023]; 

    integer i;

    always_ff @(posedge clk) begin
        if(rst_n) begin
            for(i=0; i<1024; i++) begin
                mem[i] <= 8'h00;
            end

            //Optional example values at address 0x0 
            mem[0] <= 8'h05;
            mem[1] <= 8'h00;
            mem[2] <= 8'h00;
            mem[3] <= 8'h00;
            mem[4] <= 8'h00;
            mem[5] <= 8'h00;
            mem[6] <= 8'h00;
            mem[7] <= 8'h00;
        end
        else begin 
            if(write_en) begin
                mem[addr] <= write_data[7:0];
                mem[addr+1] <= write_data[15:8];
                mem[addr+2] <= write_data[23:16];
                mem[addr+3] <= write_data[31:24];
                mem[addr+4] <= write_data[39:32];
                mem[addr+5] <= write_data[47:40];
                mem[addr+6] <= write_data[55:48];
                mem[addr+7] <= write_data[63:56];
            end
        end
    end

    assign read_data = read_en ? {mem[addr+7], mem[addr+6], mem[addr+5], mem[addr+4], mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]} : 64'h0;

endmodule