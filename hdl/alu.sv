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
    reg [55:0] ax, ay;
    reg [56:0] sum;
    reg [52:0] mr;
    reg guard, round_bit, sticky;
    integer k;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]};
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sy = sy ^ do_sub;  // flip sign of y for sub

      // zero checks return  *other* op wo changing
      if (ex == 0) begin
        fp_add = {sy, ey, my[51:0]};  // x is zero/denormal → return y (with possibly flipped sign)
      end else if (ey == 0) begin
        fp_add = {sx, ex, mx[51:0]};  // y is zero/denormal → return x
      end else begin
        // align mantissas: shift the smaller-exp one right
        if (ex >= ey) begin
          ediff = ex - ey;
          ax = {1'b0, mx, 2'b0};
          if (ediff >= 56) ay = 56'd0;
          else ay = ({1'b0, my, 2'b0} >> ediff);
          er = ex;
        end else begin
          ediff = ey - ex;
          ay = {1'b0, my, 2'b0};
          if (ediff >= 56) ax = 56'd0;
          else ax = ({1'b0, mx, 2'b0} >> ediff);
          er = ey;
        end

        // add magnitudes if signs match, sub if they differ
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

        // normalize
        if (sum == 0) begin
          fp_add = 64'd0;
        end else begin
          if (sum[56] || sum[55]) begin
            // carry out: result overflowed into bit 56 or 55, shift right one
            guard     = sum[2];
            round_bit = sum[1];
            sticky    = sum[0];
            mr        = sum[56:4];
            er        = er + 1;
          end else begin
            //shift left until bit 54 of the 57-bit sum is 1 (i.e. sum[54] == 1).
            begin : norm
              reg [56:0] s;
              s = sum;
              while (s[54] == 0 && s != 0) begin
                s  = s << 1;
                er = er - 1;
              end
              mr        = s[54:2];   // 53 mantissa bits
              guard     = s[1];
              round_bit = s[0];
              sticky    = 0;
            end
          end
          // round to nearest even
          if (guard && (round_bit || sticky || mr[0])) mr = mr + 1;
          // rounding can carry into bit 52, making mr[52] == 1.
          // The original check was inverted (tested for mr[52]==0).
          if (mr[52]) begin
            mr = mr >> 1;
            er = er + 1;
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
    reg [105:0] prod;  // 53-bit * 53-bit product needs up to 106 bits
    reg [ 52:0] mr;
    reg guard, round_bit, sticky;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]};
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sr = sx ^ sy;

      if (ex == 0 || ey == 0) begin
        fp_mul = 64'd0;
      end else begin
        er   = ex + ey - 11'd1023;
        prod = mx * my;
        if (prod[105]) begin
          mr        = prod[104:52];
          guard     = prod[51];
          round_bit = prod[50];
          sticky    = |prod[49:0];
          er        = er + 1;
        end else begin
          mr        = prod[104:52];
          guard     = prod[50];
          round_bit = prod[49];
          sticky    = |prod[48:0];
        end
        // round to nearest even
        if (guard && (round_bit || sticky || mr[0])) mr = mr + 1;
        if (mr[52]) begin
          mr = mr >> 1;
          er = er + 1;
        end
        fp_mul = {sr, er, mr[51:0]};
      end
    end
  endfunction

  // fp divide
  function automatic [63:0] fp_div;
    input [63:0] x, y;
    reg sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [107:0] num;  // mx shifted left 55 bits
    reg [ 54:0] qr;  // quotient: 53 mantissa bits + guard + round
    reg [107:0] rem;
    reg [ 52:0] mr;
    reg guard, round_bit, sticky;
    begin
      sx = x[63];
      ex = x[62:52];
      mx = {1'b1, x[51:0]};
      sy = y[63];
      ey = y[62:52];
      my = {1'b1, y[51:0]};
      sr = sx ^ sy;

      if (ey == 0 || my == 0) begin
        // divide by zero → inf
        fp_div = {sr, 11'h7FF, 52'd0};
      end else if (ex == 0 || mx == 0) begin
        fp_div = 64'd0;
      end else begin
        er  = ex - ey + 11'd1023;
        num = {mx, 55'd0};
        qr  = num / my;
        rem = num % my;
        // normalize: leading 1 should be at bit 54 of the 55-bit qr
        if (qr[54]) begin
          // result mantissa is qr[54:2], guard=qr[1], round=qr[0]
          mr        = qr[54:2];
          guard     = qr[1];
          round_bit = qr[0];
          er        = er + 1;
        end else begin
          // result mantissa is qr[53:1], guard=qr[0], round=0
          mr        = qr[53:1];
          guard     = qr[0];
          round_bit = 1'b0;
        end
        sticky = (rem != 0) ? 1'b1 : 1'b0;
        // round to nearest even
        if (guard && (round_bit || sticky || mr[0])) mr = mr + 1;
        if (mr[52]) begin
          mr = mr >> 1;
          er = er + 1;
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
      5'd11: result = fp_add(a, b, 1'b1);  // subf
      5'd12: result = fp_mul(a, b);
      5'd13: result = fp_div(a, b);

      5'd14: result = (a != 64'd0) ? 64'd1 : 64'd0;          // CMPNZ for brnz
      5'd15: result = ($signed(a) > $signed(b)) ? 64'd1 : 64'd0; // CMPGT for brgt

      default: result = 64'd0;
    endcase
  end

endmodule