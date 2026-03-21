module testing;

reg clk;
reg [31:0] instr;

tinker_sim cpu(clk, instr);

// clk
always #5 clk = ~clk;

// instr helpers
function [31:0] make_addi;
    input [4:0] rd;
    input [11:0] imm;
    begin
        make_addi = (5'h19 << 27) | (rd << 22) | imm;
    end
endfunction

function [31:0] make_add;
    input [4:0] rd, rs, rt;
    begin
        make_add = (5'h18 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
endfunction

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, testing);

    clk = 0;

    // r1 = 5
    instr = make_addi(5'd1, 12'd5);
    #10;

    // r2 = 10
    instr = make_addi(5'd2, 12'd10);
    #10;

    // r3 = r1 + r2
    instr = make_add(5'd3, 5'd1, 5'd2);
    #10;

    $display("time=%0t r1=%0d r2=%0d r3=%0d",
         $time,
         cpu.rf0.regs[1],
         cpu.rf0.regs[2],
         cpu.rf0.regs[3]);

    $finish;
end

endmodule