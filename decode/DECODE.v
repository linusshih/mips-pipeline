`timescale 1ns / 1ps

module decode(
    input wire          clk,
                        rst,
                        wb_reg_write,
    input wire [4:0]    wb_write_reg_location,
    input wire [31:0]   mem_wb_write_data,
                        if_id_instr,
                        if_id_npc,
    output wire [1:0]   id_ex_wb,
    output wire [2:0]   id_ex_mem,
    output wire [3:0]   id_ex_execute,
    output wire [31:0]  id_ex_npc,
                        id_ex_readdat1,
                        id_ex_readdat2,
                        id_ex_sign_ext,
    output wire [4:0]   id_ex_instr_bits_20_16,
                        id_ex_instr_bits_15_11
);

    wire [31:0] sign_ext_internal;
    wire [31:0] readdat1_internal;
    wire [31:0] readdat2_internal;
    wire [1:0] wb_internal;
    wire [2:0] mem_internal;
    wire [3:0] ex_internal;

    signExt sE0 (
        .immediate(if_id_instr[15:0]),
        .extended(sign_ext_internal)
    );

    regfile rf0 (
        .clk(clk),
        .rst(rst),
        .regwrite(wb_reg_write),
        .rs(if_id_instr[25:21]),
        .rt(if_id_instr[20:16]),
        .rd(wb_write_reg_location),
        .writedata(mem_wb_write_data),
        .A_readdat1(readdat1_internal),
        .B_readdat2(readdat2_internal)
    );

    control c0 (
        .clk(clk),
        .rst(rst),
        .opcode(if_id_instr[31:26]),
        .wb(wb_internal),
        .mem(mem_internal),
        .ex(ex_internal)
    ); 

    idExLatch iEL0 (
        .clk(clk),
        .rst(rst),
        .ctl_wb(wb_internal),
        .ctl_mem(mem_internal),
        .ctl_ex(ex_internal),
        .npc(if_id_npc),
        .readdat1(readdat1_internal),
        .readdat2(readdat2_internal),
        .sign_ext(sign_ext_internal),
        .instr_bits_20_16(if_id_instr[20:16]),
        .instr_bits_15_11(if_id_instr[15:11]),
        .wb_out(id_ex_wb),
        .mem_out(id_ex_mem),
        .ctl_out(id_ex_execute),
        .npc_out(id_ex_npc),
        .readdat1_out(id_ex_readdat1),
        .readdat2_out(id_ex_readdat2),
        .sign_ext_out(id_ex_sign_ext),
        .instr_bits_20_16_out(id_ex_instr_bits_20_16),
        .instr_bits_15_11_out(id_ex_instr_bits_15_11)
    );

endmodule

module signExt(
    input wire [15:0] immediate,
    output wire [31:0] extended
);

    assign extended = {{16{immediate[15]}}, immediate};
endmodule

`timescale 1ns / 1ps

module regfile(
    input wire clk, rst, regwrite, 
    input wire [4:0] rs, rt, rd,
    input wire [31:0] writedata,
    output reg [31:0] A_readdat1, B_readdat2   
);

    reg [31:0] REG [0:31];
    
    wire [31:0] r1_val;

    
    integer i;

    initial 
    begin
            for (i = 0; i < 32; i = i + 1)
                REG[i] <= 0;
    end
    assign r1_val = REG[1];

    
    always @(*) begin
        if (rst) begin
            A_readdat1 <= 32'b0;
            B_readdat2 <= 32'b0;
        end
        else begin
            if (regwrite) begin
            //overwrite the value location rd within reg with writedata
                REG[rd] <= writedata;
            end
            else begin
                //set A_readdat1 to the value at location rs within REG
                A_readdat1 <= REG[rs];
                //set B_readdat2 to the value at location rt within REG
                B_readdat2 <= REG[rt];
            end 
        end
    end
    
endmodule


module control(
    input wire clk, rst,
    input wire [5:0] opcode,
    output reg [1:0] wb,
    output reg [2:0] mem,
    output reg [3:0] ex
);
    parameter RTYPE = 6'b000000;
    parameter LW = 6'b100011; //load word
    parameter SW = 6'b101011; //store word
    parameter BEQ = 6'b000100; //branch equal 
    parameter NOP = 6'b100000; //no op
    
    initial begin
        wb = 2'd0;
        mem = 3'd0;
        ex = 4'd0;
    end
    
    always @(posedge clk) begin
        if (rst) begin
            wb <= 2'd0;
            mem <= 3'd0;
            ex <= 4'd0;
        end
        case (opcode)
            RTYPE: begin
                wb <= 2'b10;
                mem <= 3'b000;
                ex <= 4'b1100;
            end
            
            LW: begin
                wb <= 2'b11;
                mem <= 3'b010;
                ex <= 4'b0001;
            end
            
            SW: begin
                wb <= 2'b00;
                mem <= 3'b001;
                ex <= 4'b0001;
            end
            
            BEQ: begin
                wb <= 2'b00;
                mem <= 3'b100;
                ex <= 4'b0100;
            end
            
            default: begin 
                wb <= 2'b0;
                mem <= 3'b0;
                ex <= 4'b0;
            end
        endcase
    end
endmodule

module idExLatch(
    input wire clk, rst,
    input wire [1:0] ctl_wb,
    input wire [2:0] ctl_mem,
    input wire [3:0] ctl_ex,
    input wire [31:0] npc, readdat1, readdat2, sign_ext, 
    input wire [4:0] instr_bits_20_16, instr_bits_15_11, 
    output reg [1:0] wb_out, 
    output reg [2:0] mem_out,
    output reg [3:0] ctl_out,
    output reg [31:0] npc_out, readdat1_out, readdat2_out, sign_ext_out, 
    output reg [4:0] instr_bits_20_16_out, instr_bits_15_11_out
);
    
    always @(posedge clk) begin
        if (rst) begin
            wb_out <= 2'b00;
            mem_out <= 3'b000;
            ctl_out <= 4'b0000;
            npc_out <= 32'b0;
            readdat1_out <= 32'b0;
            readdat2_out <= 32'b0;
            sign_ext_out <= 32'b0;
            instr_bits_20_16_out <= 5'b00000;
            instr_bits_15_11_out <= 5'b00000;
        end
        else begin
            wb_out <= ctl_wb;
            wb_out <= ctl_wb;
            mem_out <= ctl_mem;
            ctl_out <= ctl_ex;
            npc_out <= npc;
            readdat1_out <= readdat1;
            readdat2_out <= readdat2;
            sign_ext_out <= sign_ext;
            instr_bits_20_16_out <= instr_bits_20_16;
            instr_bits_15_11_out <= instr_bits_15_11;
        end
    end    
endmodule
