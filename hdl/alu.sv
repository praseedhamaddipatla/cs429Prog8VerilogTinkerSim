module alu (
    input [63:0] a,
    input [63:0] b,
    input [4:0] op,
    output reg [63:0] result
);

  // fp_add / fp_sub
  function automatic [63:0] fp_add;
    input [63:0] x, y;
    input do_sub;
    reg        sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [10:0] ediff;
    reg [55:0] ax, ay;
    reg [56:0] sum;
    reg [53:0] mr;
    reg        guard, round_bit, sticky;
    begin
      sx = x[63]; ex = x[62:52]; mx = {1'b1, x[51:0]};
      sy = y[63]; ey = y[62:52]; my = {1'b1, y[51:0]};
      sy = sy ^ do_sub;

      if (ex == 0) begin
        fp_add = {sy, ey, my[51:0]};
      end else if (ey == 0) begin
        fp_add = {sx, ex, mx[51:0]};
      end else begin
        if (ex >= ey) begin
          ediff = ex - ey;
          ax    = {1'b0, mx, 2'b0};
          ay    = (ediff >= 56) ? 56'd0 : ({1'b0, my, 2'b0} >> ediff);
          er    = ex;
        end else begin
          ediff = ey - ex;
          ay    = {1'b0, my, 2'b0};
          ax    = (ediff >= 56) ? 56'd0 : ({1'b0, mx, 2'b0} >> ediff);
          er    = ey;
        end

        if (sx == sy) begin
          sum = ax + ay; sr = sx;
        end else if (ax >= ay) begin
          sum = ax - ay; sr = sx;
        end else begin
          sum = ay - ax; sr = sy;
        end

        if (sum == 0) begin
          fp_add = 64'd0;
        end else begin
          if (sum[55]) begin
            // Carry: leading-1 at sum[55].  Shift right 1 => mr = sum[55:3].
            mr        = {1'b0, sum[55:3]};
            guard     = sum[2];
            round_bit = sum[1];
            sticky    = sum[0];
            er        = er + 1;
          end else begin
            begin : norm_loop
              reg [56:0] s;
              s = sum;
              while (s[54] == 0 && s != 0) begin
                s  = s << 1;
                er = er - 1;
              end
              mr        = {1'b0, s[54:2]};
              guard     = s[1];
              round_bit = s[0];
              sticky    = 1'b0;
            end
          end

          if (guard && (round_bit || sticky || mr[0]))
            mr = mr + 54'd1;

          // mr[53] set means rounding overflowed into a 54th bit
          if (mr[53]) begin
            mr = mr >> 1;
            er = er + 1;
          end

          fp_add = {sr, er, mr[51:0]};
        end
      end
    end
  endfunction

  // fp_mul

  function automatic [63:0] fp_mul;
    input [63:0] x, y;
    reg        sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [105:0] prod;
    reg [53:0]  mr;
    reg         guard, round_bit, sticky;
    begin
      sx = x[63]; ex = x[62:52]; mx = {1'b1, x[51:0]};
      sy = y[63]; ey = y[62:52]; my = {1'b1, y[51:0]};
      sr = sx ^ sy;

      if (ex == 0 || ey == 0) begin
        fp_mul = 64'd0;
      end else begin
        er   = ex + ey - 11'd1023;
        prod = mx * my;

        if (prod[105]) begin
          // leading-1 at prod[105]; shift right 1
          mr        = {1'b0, prod[105:53]};
          guard     = prod[52];
          round_bit = prod[51];
          sticky    = |prod[50:0];
          er        = er + 1;
        end else begin
          // leading-1 at prod[104]
          mr        = {1'b0, prod[104:52]};
          guard     = prod[51];
          round_bit = prod[50];
          sticky    = |prod[49:0];
        end

        if (guard && (round_bit || sticky || mr[0]))
          mr = mr + 54'd1;

        if (mr[53]) begin
          mr = mr >> 1;
          er = er + 1;
        end

        fp_mul = {sr, er, mr[51:0]};
      end
    end
  endfunction


//fp div
  function automatic [63:0] fp_div;
    input [63:0] x, y;
    reg        sx, sy, sr;
    reg [10:0] ex, ey, er;
    reg [52:0] mx, my;
    reg [107:0] num;
    reg [ 54:0] qr;
    reg [107:0] rem;
    reg [ 53:0] mr;
    reg         guard, round_bit, sticky;
    begin
      sx = x[63]; ex = x[62:52]; mx = {1'b1, x[51:0]};
      sy = y[63]; ey = y[62:52]; my = {1'b1, y[51:0]};
      sr = sx ^ sy;

      if (ey == 0) begin
        fp_div = {sr, 11'h7FF, 52'd0};  // divide by zero => infinity
      end else if (ex == 0) begin
        fp_div = 64'd0;
      end else begin
        er  = ex - ey + 11'd1023;
        num = {mx, 55'd0};
        qr  = num / my;
        rem = num % my;

        if (qr[54]) begin
          // mx/my >= 1.0: leading-1 at qr[54]
          // mr = qr[54:2], guard=qr[1], round=qr[0], er unchanged
          mr        = {1'b0, qr[54:2]};
          guard     = qr[1];
          round_bit = qr[0];
        end else begin
          // mx/my < 1.0: leading-1 at qr[53]
          // mr = qr[53:1], guard=qr[0], round=0, er -= 1
          mr        = {1'b0, qr[53:1]};
          guard     = qr[0];
          round_bit = 1'b0;
          er        = er - 1;
        end

        sticky = (rem != 0) ? 1'b1 : 1'b0;

        if (guard && (round_bit || sticky || mr[0]))
          mr = mr + 54'd1;

        if (mr[53]) begin
          mr = mr >> 1;
          er = er + 1;
        end

        fp_div = {sr, er, mr[51:0]};
      end
    end
  endfunction

  always @(*) begin
    case (op)
      5'd0:  result = a + b;
      5'd1:  result = a - b;
      5'd2:  result = a * b;
      5'd3:  result = (b == 0) ? 64'd0 : $signed(a) / $signed(b);

      5'd4:  result = a & b;
      5'd5:  result = a | b;
      5'd6:  result = a ^ b;
      5'd7:  result = ~a;
      5'd8:  result = a >> b[5:0];
      5'd9:  result = a << b[5:0];

      5'd10: result = fp_add(a, b, 1'b0);
      5'd11: result = fp_add(a, b, 1'b1);
      5'd12: result = fp_mul(a, b);
      5'd13: result = fp_div(a, b);

      5'd14: result = (a != 64'd0) ? 64'd1 : 64'd0;
      5'd15: result = ($signed(a) > $signed(b)) ? 64'd1 : 64'd0;

      default: result = 64'd0;
    endcase
  end

endmodule