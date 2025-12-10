`timescale 1ns / 1ps

module execute(
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  wb_ctl,
    input  wire [2:0]  m_ctl,
    input  wire        regdst,
    input  wire        alusrc,
    input  wire [1:0]  aluop,
    input  wire [31:0] npcout,
    input  wire [31:0] rdata1,
    input  wire [31:0] rdata2,
    input  wire [31:0] s_extendout,
    input  wire [4:0]  instrout_2016,
    input  wire [4:0]  instrout_1511,
    input  wire [5:0]  funct,
    output wire [1:0]  wb_ctlout,
    output wire        branch,
    output wire        memread,
    output wire        memwrite,
    output wire [31:0] EX_MEM_NPC,
    output wire        zero,
    output wire [31:0] alu_result,
    output wire [31:0] rdata2out,
    output wire [4:0]  five_bit_muxout
);

wire [31:0] shifted_imm;
wire [31:0] adder_out;
wire [31:0] b_input;
wire [31:0] aluout;
wire [4:0]  reg_mux_out;
wire [2:0]  alu_ctrl;
wire        aluzero;

assign shifted_imm = s_extendout << 2;

adder adder3 (
    .add_in1(npcout),
    .add_in2(shifted_imm),
    .add_out(adder_out)
);

bottom_mux bottom_mux3 (
    .a(instrout_2016),
    .b(instrout_1511),
    .sel(regdst),
    .y(reg_mux_out)
);

alu_control alu_control3 (
    .funct(funct),
    .aluop(aluop),
    .select(alu_ctrl)
);

top_mux top_mux3 (
    .a(rdata2),
    .b(s_extendout),
    .sel(alusrc),
    .y(b_input)
);

alu alu3 (
    .a(rdata1),
    .b(b_input),
    .control(alu_ctrl),
    .result(aluout),
    .zero(aluzero)
);

ex_mem ex_mem3 (
    .clk(clk),
    .reset(reset),
    .ctlwb_in(wb_ctl),
    .ctlm_in(m_ctl),
    .adder_in(adder_out),
    .zero_in(aluzero),
    .alu_in(aluout),
    .rdata2_in(rdata2),
    .mux_in(reg_mux_out),
    .ctlwb_out(wb_ctlout),
    .branch(branch),
    .memread(memread),
    .memwrite(memwrite),
    .add_result(EX_MEM_NPC),
    .zero(zero),
    .alu_result(alu_result),
    .rdata2_out(rdata2out),
    .five_bit_muxout(five_bit_muxout)
);

endmodule

module adder(
    input wire [31:0] add_in1,
    input wire [31:0] add_in2,
    output wire [31:0] add_out
    );
 
    assign add_out = add_in1 + add_in2;
endmodule

module bottom_mux(
    input  wire [4:0] a,   
    input  wire [4:0] b,   
    input  wire sel,
    output wire [4:0] y    
);

    assign y = sel ? a : b;

endmodule

module alu_control(
    input  wire [5:0] funct,
    input  wire [1:0] aluop,
    output reg  [2:0] select
);

    // ALUOp encodings (from main control unit)
    localparam Rtype  = 2'b10;    // use funct field
    localparam LW_SW  = 2'b00;    // load/store ? add
    localparam BEQ    = 2'b01;    // beq ? subtract
    localparam UNKNOWN= 2'b11;    // invalid / don't care

    // ALU control outputs
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    localparam ALU_X   = 3'b011;   // undefined operation

    // R-type funct field encodings
    localparam FUNCT_ADD = 6'b100000;
    localparam FUNCT_SUB = 6'b100010;
    localparam FUNCT_AND = 6'b100100;
    localparam FUNCT_OR  = 6'b100101;
    localparam FUNCT_SLT = 6'b101010;

    always @(*) begin
        case (aluop)

            // R-type ? decode using funct field
            Rtype: begin
                case (funct)
                    FUNCT_ADD: select = ALU_ADD;
                    FUNCT_SUB: select = ALU_SUB;
                    FUNCT_AND: select = ALU_AND;
                    FUNCT_OR:  select = ALU_OR;
                    FUNCT_SLT: select = ALU_SLT;
                    default:    select = ALU_X;
                endcase
            end

            // LW, SW
            LW_SW: select = ALU_ADD;

            // BEQ
            BEQ:   select = ALU_SUB;

            // Unknown ALUOp ? don't care operation
            UNKNOWN: select = ALU_X;

            // Safety default
            default: select = ALU_X;
        endcase
    end
endmodule

module top_mux(
    input  wire [31:0] a,   
    input  wire [31:0] b,   
    input  wire sel,
    output wire [31:0] y      
);

    assign y = sel ? a : b;

endmodule

module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  control,
    output reg  [31:0] result,
    output wire        zero
);

    // ALU operation codes (match alu_control)
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_X   = 3'b011;     // unused/don't care
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;

    always @(*) begin
        case (control)

            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;

            // Proper signed SLT (set-on-less-than)
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

            default: result = 32'hXXXXXXXX;
        endcase
    end

    // Zero flag
    assign zero = (result == 32'd0);

endmodule

module ex_mem(
    input  wire        clk,
    input  wire        reset,

    // incoming control and datapath signals from EXECUTE
    input  wire [1:0]  ctlwb_in,
    input  wire [2:0]  ctlm_in,
    input  wire [31:0] adder_in,
    input  wire        zero_in,
    input  wire [31:0] alu_in,
    input  wire [31:0] rdata2_in,
    input  wire [4:0]  mux_in,

    // registered outputs to MEM stage
    output reg [1:0]   ctlwb_out,
    output reg         branch,
    output reg         memread,
    output reg         memwrite,
    output reg [31:0]  add_result,
    output reg         zero,
    output reg [31:0]  alu_result,
    output reg [31:0]  rdata2_out,
    output reg [4:0]   five_bit_muxout
);

    // synchronous reset
    always @(posedge clk) begin
        if (reset) begin
            ctlwb_out      <= 0;
            branch         <= 0;
            memread        <= 0;
            memwrite       <= 0;
            add_result     <= 0;
            zero           <= 0;
            alu_result     <= 0;
            rdata2_out     <= 0;
            five_bit_muxout<= 0;
        end 
        else begin
            ctlwb_out      <= ctlwb_in;
            branch         <= ctlm_in[2];
            memread        <= ctlm_in[1];
            memwrite       <= ctlm_in[0];
            add_result     <= adder_in;
            zero           <= zero_in;
            alu_result     <= alu_in;
            rdata2_out     <= rdata2_in;
            five_bit_muxout<= mux_in;
        end
    end
endmodule

