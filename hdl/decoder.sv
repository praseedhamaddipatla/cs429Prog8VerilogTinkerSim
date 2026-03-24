module decoder(
    input [31:0] instr,
    output reg [4:0] raddr1,
    output reg [4:0] raddr2,
    output reg [4:0] waddr,
    output reg [63:0] immediate,
    output reg [4:0] op,
    output reg use_imm,
    output reg write
);

//break down instr
wire [4:0] opcode = instr[31:27];
wire [4:0] rd = instr[26:22];
wire [4:0] rs = instr[21:17];
wire [4:0] rt = instr[16:12];
wire [15:0] imm = instr[11:0];

//alu codes
localparam ADD = 5'd0;
localparam SUB = 5'd1;
localparam MUL = 5'd2;
localparam DIV = 5'd3;
localparam AND = 5'd4;
localparam OR  = 5'd5;
localparam XOR = 5'd6;
localparam NOT = 5'd7;
localparam SHR = 5'd8;
localparam SHL = 5'd9;
localparam ADDF = 5'd10;
localparam SUBF = 5'd11;
localparam MULF = 5'd12;
localparam DIVF = 5'd13;

always @(*) begin
    //reset
    raddr1=5'd0;
    raddr2=5'd0;
    waddr=5'd0;
    op=ADD;
    use_imm=0;
    write=0;

    //set for alu
    case(opcode)
        //int arithmetic
        5'h18: begin // add
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = ADD;
        write = 1;
    end

    5'h19: begin // addi
        raddr1 = rd;
        waddr = rd;

        immediate = {{52{imm[11]}}, imm}; // sign extend
        op = ADD;
        use_imm = 1;
        write = 1;
    end

    5'h1A: begin // sub
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = SUB;
        write = 1;
    end

    5'h1B: begin // subi
        raddr1 = rd;
        waddr = rd;

        immediate = {{52{imm[11]}}, imm};
        op = SUB;
        use_imm = 1;
        write = 1;
    end

    5'h1C: begin // mul
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = MUL;
        write = 1;
    end

    5'h1D: begin // div
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = DIV;
        write = 1;
    end

    // logic
    5'h00: begin // and
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = AND;
        write = 1;
    end

    5'h01: begin // or
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = OR;
        write = 1;
    end

    5'h02: begin // xor
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = XOR;
        write = 1;
    end

    5'h03: begin // not
        raddr1 = rs;
        waddr = rd;

        op = NOT;
        write = 1;
    end

    //shifts
    5'h04: begin // shftr
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = SHR;
        write = 1;
    end

    5'h05: begin // shftri
        raddr1 = rd;
        waddr = rd;

        immediate = {{52{1'b0}}, imm};
        op = SHR;
        use_imm = 1;
        write = 1;
    end

    5'h06: begin // shftl
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = SHL;
        write = 1;
    end

    5'h07: begin // shftli
        raddr1 = rd;
        waddr = rd;

        immediate = {{52{1'b0}}, imm};
        op = SHL;
        use_imm = 1;
        write = 1;
    end

    //floats
    5'h14: begin // addf
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = ADDF;
        write = 1;
    end

    5'h15: begin // subf
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = SUBF;
        write = 1;
    end

    5'h16: begin // mulf
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = MULF;
        write = 1;
    end

    5'h17: begin // divf
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;

        op = DIVF;
        write = 1;
    end

        default: begin
        end
    endcase
end

endmodule