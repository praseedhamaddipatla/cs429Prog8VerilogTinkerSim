module alu (
    input [63:0] a,
    input [63:0] b,
    input [4:0] op,
    output reg [63:0] result
);

  // fp add / sub
  // passing do_sub=1 flips the sign of y
  function automatic [63:0] fp_add;
    input [63:0] x, y;
    input do_sub;
    reg sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;  // 53 bits with the implicit leading 1 restored
    reg [10:0] ediff;
    reg [53:0] ax, ay;  // extra guard bit for alignment shifts
    reg [54:0] sum;
    reg [52:0] mr;
    integer k;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]}; //add implicit 1 back to mantissa
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sy = sy ^ do_sub;  // flip sign of y for sub

      if (ex == 0) begin
        fp_add = {sy, ey, my[51:0]};
      end else if (ey == 0) begin
        fp_add = {sx, ex, mx[51:0]};
      end else begin
        // align mantissas: shift num with smaller exponent right
        if (ex >= ey) begin
          ediff = ex - ey;
          ax = {1'b0, mx};
          ay = (ediff >= 54) ? 54'd0 : ({1'b0, my} >> ediff);
          er = ex;
        end else begin
          ediff = ey - ex;
          ay = {1'b0, my};
          ax = (ediff >= 54) ? 54'd0 : ({1'b0, mx} >> ediff);
          er = ey;
        end

        // add magnitudes if signs match, subtract if differ
        if (sx == sy) begin
          sum = ax + ay;
          sr  = sx;
        end else begin
          if (ax >= ay) begin
            sum = ax - ay;
            sr  = sx;
          end else begin
            sum = ay - ax;
            sr  = sy;
          end
        end

        // normalize: find the leading 1 and adjust exp
        if (sum == 0) begin
          fp_add = 64'd0;
        end else begin
          mr = sum[52:0];
          if (sum[54] || sum[53]) begin
            // overflow into the carry bit: shift right and bump exp
            mr = sum[54:2];
            er = er + 1;
          end else begin
            // shift left until bit 52 is 1
            k = 0;
            while (k < 53 && mr[52] == 0) begin
              mr = mr << 1;
              er = er - 1;
              k  = k + 1;
            end
          end
          fp_add = {sr, er, mr[51:0]};
        end
      end
    end
  endfunction

  // fp multiply
  function automatic [63:0] fp_mul;
    input [63:0] x, y;
    reg sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [105:0] prod;  // 53-bit * 53-bit so max 106 bits
    reg [ 52:0] mr;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]};
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sr = sx ^ sy;  // result sign is xor of input signs

      if (ex == 0 || ey == 0) begin
        fp_mul = 64'd0;
      end else begin
        // add biased exp then sub one bias
        er   = ex + ey - 11'd1023;
        prod = mx * my;
        // leading 1 lands at bit 105 or 104
        if (prod[105]) begin
          mr = prod[104:52];
          er = er + 1;
        end else begin
          mr = prod[103:51];
        end
        fp_mul = {sr, er, mr[51:0]};
      end
    end
  endfunction

  // fp divide
  // shift the numerator left 53 bits before integer div
  function automatic [63:0] fp_div;
    input [63:0] x, y;
    reg sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [105:0] num;
    reg [ 52:0] mr;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]};
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sr = sx ^ sy;

      if (ey == 0 || my == 0) begin
        // div by zero: return inf
        fp_div = {sr, 11'h7FF, 52'd0};
      end else if (ex == 0 || mx == 0) begin
        fp_div = 64'd0;
      end else begin
        // subtract biased exp then add bias back
        er  = ex - ey + 11'd1023;
        num = {mx, 53'd0};  // shift left for precision
        mr  = num / my;
        if (!mr[52]) begin
          // leading 1 is one place too low, shift and adjust exp
          mr = mr << 1;
          er = er - 1;
        end
        fp_div = {sr, er, mr[51:0]};
      end
    end
  endfunction

  always @(*) begin
    case (op)
      // integer arithmetic
      5'd0: result = a + b;
      5'd1: result = a - b;
      5'd2: result = a * b;
      5'd3: result = (b == 0) ? 64'd0 : $signed(a) / $signed(b);  // signed division

      // bitwise and shift
      5'd4: result = a & b;
      5'd5: result = a | b;
      5'd6: result = a ^ b;
      5'd7: result = ~a;  // b is unused for not
      5'd8: result = a >> b[5:0];  // logical right shift
      5'd9: result = a << b[5:0];

      // floating point
      5'd10: result = fp_add(a, b, 1'b0);  // addf
      5'd11: result = fp_add(a, b, 1'b1);  // subf - do_sub flips sign of b
      5'd12: result = fp_mul(a, b);
      5'd13: result = fp_div(a, b);

      default: result = 64'd0;
    endcase
  end

endmodule
