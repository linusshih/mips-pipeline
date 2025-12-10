module pc (
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 32'b0;
        else
            pc_out <= pc_in;
    end
endmodule

module incrementer ( //(adder)
    input wire clk,
    input wire rst,
    input wire [31:0] pcin,
    output reg [31:0] pcout
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            pcout <= 32'b0;
        else
            pcout <= pcin + 32'd4;
    end
endmodule
