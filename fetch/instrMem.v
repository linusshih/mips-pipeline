module instrMem (
    input wire clk,
    input wire rst,
    input wire [31:0] addr,
    output reg [31:0] data
);
    //reg [31:0] mem [0:(2**32)-1];
    reg [31:0] mem [0:31];
    
    integer i = 0;
    initial begin
        $readmemb("risc.txt", mem);
//        for (i = 0; i<24; i = i+1)
//            $display(mem[i]);
    end
