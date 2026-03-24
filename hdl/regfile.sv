module reg_file(
    input [63:0] data,
    input [4:0] raddr1,
    input [4:0] raddr2,
    input [4:0] waddr,
    input clk,
    input write,
    output reg [63:0] r1,
    output reg [63:0] r2
);

    reg [63:0] registers [0:31];

    integer i;
    initial begin
        for(i=0; i<32; i=i+1)
            registers[i]=64'd0;
    end

    assign r1=registers[raddr1];
    assign r2=registers[raddr2];

    always @(posedge clk) begin
        if (write) begin
            registers[waddr]<=data;
        end
    end

endmodule