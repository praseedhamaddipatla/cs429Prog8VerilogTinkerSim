module alu(
    input [63:0] a,
    input [63:0] b,
    input [4:0] op,
    output reg [63:0] result
);

//fix floating point implementation
always @(*) begin
    case (op)
        //int arithmetic
        5'd0: result = a + b;
        5'd1: result = a - b;
        5'd2: result = a * b;
        5'd3: result = a / b;

        //bit ops and shifts
        5'd4: result = a & b;
        5'd5: result = a | b;
        5'd6: result = a ^ b;
        5'd7: result = ~a;
        5'd8: result = a >> b[5:0];
        5'd9: result = a << b[5:0];

        //floats -- FIXXX
        5'd10: result = a + b;
        5'd11: result = a - b;
        5'd12: result = a * b;
        5'd13: result = a / b;
        default: result=64'd0;
    endcase
end

endmodule