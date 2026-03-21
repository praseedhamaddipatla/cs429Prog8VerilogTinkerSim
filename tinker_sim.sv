module tinker_sim(input clk, input [31:0] instr);

    //wires
    wire [4:0] raddr1, raddr2, waddr;
    wire [63:0] data1, data2;
    wire [63:0] result;
    wire [4:0] op;
    wire write;
    wire use_imm;
    wire [63:0] immediate;
    wire [63:0] alu2;

    decoder d0(instr, raddr1, raddr2, waddr, immediate, op, use_imm, write);
    assign alu2 = (use_imm) ? immediate : data2;
    regfile rf0(
        .clk(clk),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .waddr(waddr),
        .data(result),
        .write(write),
        .r1(data1),
        .r2(data2)
    );
    alu a0(data1, alu2, op, result);

endmodule