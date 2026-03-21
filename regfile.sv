module regfile(
    input [63:0] data,
    input [4:0] raddr1,
    input [4:0] raddr2,
    input [4:0] waddr,
    input clk,
    input write,
    output reg [63:0] r1,
    output reg [63:0] r2
);

    reg [63:0] regs [31:0];

    integer i;
    initial begin
        for(i=0; i<32; i=i+1)
            regs[i]=64'd0;
    end

    assign r1=regs[raddr1];
    assign r2=regs[raddr2];

    always @(posedge clk) begin
        if (write) begin
            regs[waddr]<=data;
        end
    end

endmodule