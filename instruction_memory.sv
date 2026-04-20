module instruction_memory(
    input logic clk,
    input logic rst_n,
    input logic [63:0] addr,
    output logic [31:0] instruction
);

    // Simple instruction memory with 256 instructions (1KB)
    logic [7:0] mem[0:1023];
     
     integer i;

     always_ff @( posedge clk ) begin
        if (rst_n) begin
            for (i = 0; i < 1024; i++) begin
                mem[i] <= 8'h00; // Clear memory on reset
            end
             //load instructions here if needed, e.g.:
        mem[0] <= 8'h93; // Example instruction (ADDI x1, x0, 5)
        mem[1] <= 8'h05;
        mem[2] <= 8'h00;
        mem[3] <= 8'h00;            
    
      end
    end
    assign instruction = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
endmodule