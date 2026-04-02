module testbench;

  reg clk;
  reg reset;

  tinker_core cpu (
      .clk  (clk),
      .reset(reset)
  );

  always #5 clk = ~clk;

  integer pass_count;
  integer fail_count;

  // instruction encoding helpers
  // format: opcode[31:27] rd[26:22] rs[21:17] rt[16:12] imm[11:0]

  function [31:0] make_add;
    input [4:0] rd, rs, rt;
    begin
      make_add = (5'h18 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_addi;
    input [4:0] rd;
    input [11:0] imm;
    begin
      make_addi = (5'h19 << 27) | (rd << 22) | imm;
    end
  endfunction

  function [31:0] make_sub;
    input [4:0] rd, rs, rt;
    begin
      make_sub = (5'h1A << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_subi;
    input [4:0] rd;
    input [11:0] imm;
    begin
      make_subi = (5'h1B << 27) | (rd << 22) | imm;
    end
  endfunction

  function [31:0] make_mul;
    input [4:0] rd, rs, rt;
    begin
      make_mul = (5'h1C << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_div;
    input [4:0] rd, rs, rt;
    begin
      make_div = (5'h1D << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_and;
    input [4:0] rd, rs, rt;
    begin
      make_and = (5'h00 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_or;
    input [4:0] rd, rs, rt;
    begin
      make_or = (5'h01 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_xor;
    input [4:0] rd, rs, rt;
    begin
      make_xor = (5'h02 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_not;
    input [4:0] rd, rs;
    begin
      make_not = (5'h03 << 27) | (rd << 22) | (rs << 17);
    end
  endfunction

  function [31:0] make_shftr;
    input [4:0] rd, rs, rt;
    begin
      make_shftr = (5'h04 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_shftri;
    input [4:0] rd;
    input [11:0] imm;
    begin
      make_shftri = (5'h05 << 27) | (rd << 22) | imm;
    end
  endfunction

  function [31:0] make_shftl;
    input [4:0] rd, rs, rt;
    begin
      make_shftl = (5'h06 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_shftli;
    input [4:0] rd;
    input [11:0] imm;
    begin
      make_shftli = (5'h07 << 27) | (rd << 22) | imm;
    end
  endfunction

  function [31:0] make_br;
    input [4:0] rd;
    begin
      make_br = (5'h08 << 27) | (rd << 22);
    end
  endfunction

  function [31:0] make_brr_imm;
    input [11:0] imm;
    begin
      make_brr_imm = (5'h0A << 27) | imm;
    end
  endfunction

  function [31:0] make_brnz;
    input [4:0] rd, rs;
    begin
      make_brnz = (5'h0B << 27) | (rd << 22) | (rs << 17);
    end
  endfunction

  function [31:0] make_call;
    input [4:0] rd;
    begin
      make_call = (5'h0C << 27) | (rd << 22);
    end
  endfunction

  function [31:0] make_return;
    begin
      make_return = (5'h0D << 27);
    end
  endfunction

  function [31:0] make_brgt;
    input [4:0] rd, rs, rt;
    begin
      make_brgt = (5'h0E << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_halt;
    begin
      make_halt = (5'h0F << 27);
    end
  endfunction

  function [31:0] make_load;
    input [4:0] rd, rs;
    input [11:0] imm;
    begin
      make_load = (5'h10 << 27) | (rd << 22) | (rs << 17) | imm;
    end
  endfunction

  function [31:0] make_mov_reg;
    input [4:0] rd, rs;
    begin
      make_mov_reg = (5'h11 << 27) | (rd << 22) | (rs << 17);
    end
  endfunction

  function [31:0] make_mov_imm;
    input [4:0] rd;
    input [11:0] imm;
    begin
      make_mov_imm = (5'h12 << 27) | (rd << 22) | imm;
    end
  endfunction

  function [31:0] make_store;
    input [4:0] rd, rs;
    input [11:0] imm;
    begin
      make_store = (5'h13 << 27) | (rd << 22) | (rs << 17) | imm;
    end
  endfunction

  function [31:0] make_addf;
    input [4:0] rd, rs, rt;
    begin
      make_addf = (5'h14 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_subf;
    input [4:0] rd, rs, rt;
    begin
      make_subf = (5'h15 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_mulf;
    input [4:0] rd, rs, rt;
    begin
      make_mulf = (5'h16 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  function [31:0] make_divf;
    input [4:0] rd, rs, rt;
    begin
      make_divf = (5'h17 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  // write a 32-bit instruction little-endian into memory
  task write_instr;
    input [63:0] addr;
    input [31:0] word;
    begin
      cpu.memory.bytes[addr]   = word[7:0];
      cpu.memory.bytes[addr+1] = word[15:8];
      cpu.memory.bytes[addr+2] = word[23:16];
      cpu.memory.bytes[addr+3] = word[31:24];
    end
  endtask

  // write a 64-bit value little-endian into memory
  task write_mem64;
    input [63:0] addr;
    input [63:0] val;
    begin
      cpu.memory.bytes[addr]   = val[7:0];
      cpu.memory.bytes[addr+1] = val[15:8];
      cpu.memory.bytes[addr+2] = val[23:16];
      cpu.memory.bytes[addr+3] = val[31:24];
      cpu.memory.bytes[addr+4] = val[39:32];
      cpu.memory.bytes[addr+5] = val[47:40];
      cpu.memory.bytes[addr+6] = val[55:48];
      cpu.memory.bytes[addr+7] = val[63:56];
    end
  endtask

  // check a register and print pass/fail
  task check_reg;
    input [63:0] expected;
    input [63:0] got;
    input integer test_id;
    begin
      if (got === expected) begin
        $display("  pass [%0d]: got 0x%016h", test_id, got);
        pass_count = pass_count + 1;
      end else begin
        $display("  FAIL [%0d]: got 0x%016h  expected 0x%016h", test_id, got, expected);
        fail_count = fail_count + 1;
      end
    end
  endtask

  // pulse reset and clear the program area so tests don't bleed into each other
  task do_reset;
    integer j;
    begin
      reset = 1;
      for (j = 0; j < 512; j = j + 1) cpu.memory.bytes[64'h2000+j] = 8'h00;
      @(posedge clk);
      @(posedge clk);
      reset = 0;
    end
  endtask

  task run_cycles;
    input integer n;
    integer j;
    begin
      for (j = 0; j < n; j = j + 1) @(posedge clk);
    end
  endtask

  // -------------------------------------------------------
  // Helper: run a single FDIV through the ALU and show internals
  // Loads a and b into data memory, runs divf r4 = r2 / r3
  // -------------------------------------------------------
  task run_fdiv_debug;
    input [63:0] a_bits;   // dividend (IEEE 754 bits)
    input [63:0] b_bits;   // divisor  (IEEE 754 bits)
    input [63:0] expected; // expected result bits
    input [63:0] test_num;
    // internal fields we decode for printing
    reg        sa, sb, sr_exp;
    reg [10:0] ea, eb;
    reg [51:0] fa, fb;
    begin
      sa = a_bits[63]; ea = a_bits[62:52]; fa = a_bits[51:0];
      sb = b_bits[63]; eb = b_bits[62:52]; fb = b_bits[51:0];
      sr_exp = sa ^ sb;

      $display("------------------------------------------------------------");
      $display("FDIV debug test %0d", test_num);
      $display("  a = 0x%016h  (sign=%b exp=0x%03h mant=0x%013h)", a_bits, sa, ea, fa);
      $display("  b = 0x%016h  (sign=%b exp=0x%03h mant=0x%013h)", b_bits, sb, eb, fb);
      $display("  expected result = 0x%016h", expected);
      $display("  expected sign=%b exp=0x%03h mant=0x%013h",
               expected[63], expected[62:52], expected[51:0]);

      do_reset();
      write_mem64(64'h1000, a_bits);
      write_mem64(64'h1008, b_bits);
      write_instr(64'h2000, make_addi(5'd1, 12'h1));
      write_instr(64'h2004, make_shftli(5'd1, 12'd12));  // r1 = 0x1000
      write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));  // r2 = a
      write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));  // r3 = b
      write_instr(64'h2010, make_divf(5'd4, 5'd2, 5'd3));
      write_instr(64'h2014, make_halt());
      run_cycles(14);

      $display("  got    result = 0x%016h", cpu.reg_file.registers[4]);
      $display("  got    sign=%b exp=0x%03h mant=0x%013h",
               cpu.reg_file.registers[4][63],
               cpu.reg_file.registers[4][62:52],
               cpu.reg_file.registers[4][51:0]);

      if (cpu.reg_file.registers[4] === expected)
        $display("  >>> PASS <<<");
      else begin
        $display("  >>> FAIL <<<");
        // Show what the exponent arithmetic should be
        $display("  --- manual trace ---");
        $display("  ea=%0d (0x%03h)  eb=%0d (0x%03h)", ea, ea, eb, eb);
        $display("  er = ea - eb + 1023 = %0d - %0d + 1023 = %0d (0x%03h)",
                 ea, eb, (ea - eb + 1023), (ea - eb + 1023));
        $display("  expected result exp = %0d (0x%03h)",
                 expected[62:52], expected[62:52]);
      end
      $display("------------------------------------------------------------");
    end
  endtask

  integer i;

  initial begin
    $dumpfile("sim/wave.vcd");
    $dumpvars(0, testbench);

    clk        = 0;
    reset      = 1;
    pass_count = 0;
    fail_count = 0;

    @(posedge clk);
    @(posedge clk);
    reset = 0;

    // ================================================================
    // FDIV DEBUG SECTION
    // Tests matching the autograder's known FDIV cases
    // ================================================================
    $display("\n=== FDIV DETAILED DEBUG ===\n");

    // Test #22 basic: 1.0 / 2.0 = 0.5
    run_fdiv_debug(
      64'h3FF0000000000000,  // 1.0
      64'h4000000000000000,  // 2.0
      64'h3FE0000000000000,  // 0.5
      22
    );

    // Additional basic cases to triangulate the bug:

    // 2.0 / 1.0 = 2.0
    run_fdiv_debug(
      64'h4000000000000000,  // 2.0
      64'h3FF0000000000000,  // 1.0
      64'h4000000000000000,  // 2.0
      22
    );

    // 6.0 / 2.0 = 3.0
    run_fdiv_debug(
      64'h4018000000000000,  // 6.0
      64'h4000000000000000,  // 2.0
      64'h4008000000000000,  // 3.0
      22
    );

    // 1.0 / 3.0 = 0.333...  (tests rounding)
    run_fdiv_debug(
      64'h3FF0000000000000,  // 1.0
      64'h4008000000000000,  // 3.0
      64'h3FD5555555555555,  // 0.333... rounded
      32
    );

    // Test #36 subnormal: smallest normal / 2.0 => subnormal result
    // smallest normal = 0x0010000000000000 (exp=1, mant=0)
    // result should be 0x0008000000000000 (subnormal)
    run_fdiv_debug(
      64'h0010000000000000,  // smallest normal (~2.2e-308)
      64'h4000000000000000,  // 2.0
      64'h0008000000000000,  // subnormal
      36
    );

    // subnormal / 1.0 = same subnormal
    run_fdiv_debug(
      64'h0000000000000001,  // smallest subnormal
      64'h3FF0000000000000,  // 1.0
      64'h0000000000000001,  // same
      36
    );

    // ================================================================
    // Original testbench tests below (unchanged)
    // ================================================================

    $display("\n--- reset state ---");
    do_reset();

    begin
      integer all_zero;
      all_zero = 1;
      for (i = 0; i < 31; i = i + 1) if (cpu.reg_file.registers[i] !== 64'd0) all_zero = 0;
      if (all_zero) begin
        $display("  pass [0]: r0-r30 all zero");
        pass_count = pass_count + 1;
      end else begin
        $display("  FAIL [0]: some register not zero after reset");
        fail_count = fail_count + 1;
      end
    end

    check_reg(64'd524288, cpu.reg_file.registers[31], 1);

    $display("\n--- integer arithmetic ---");

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd20));
    write_instr(64'h2004, make_addi(5'd2, 12'd30));
    write_instr(64'h2008, make_add(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd50, cpu.reg_file.registers[3], 2);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd10));
    write_instr(64'h2004, make_addi(5'd1, 12'hFFD));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd7, cpu.reg_file.registers[1], 3);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd100));
    write_instr(64'h2004, make_addi(5'd2, 12'd40));
    write_instr(64'h2008, make_sub(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd60, cpu.reg_file.registers[3], 4);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd50));
    write_instr(64'h2004, make_subi(5'd1, 12'd7));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd43, cpu.reg_file.registers[1], 5);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd6));
    write_instr(64'h2004, make_addi(5'd2, 12'd7));
    write_instr(64'h2008, make_mul(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd42, cpu.reg_file.registers[3], 6);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd100));
    write_instr(64'h2004, make_addi(5'd2, 12'd4));
    write_instr(64'h2008, make_div(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd25, cpu.reg_file.registers[3], 7);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd5));
    write_instr(64'h2004, make_addi(5'd2, 12'd10));
    write_instr(64'h2008, make_sub(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'hFFFFFFFFFFFFFFFB, cpu.reg_file.registers[3], 8);

    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd99));
    write_instr(64'h2004, make_addi(5'd2, 12'd0));
    write_instr(64'h2008, make_mul(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd0, cpu.reg_file.registers[3], 9);

    $display("\n--- floating point ---");

    // addf: 1.0 + 2.0 = 3.0
    do_reset();
    write_mem64(64'h1000, 64'h3FF0000000000000);
    write_mem64(64'h1008, 64'h4000000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_addf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'h4008000000000000, cpu.reg_file.registers[4], 34);

    // subf: 3.0 - 1.0 = 2.0
    do_reset();
    write_mem64(64'h1000, 64'h4008000000000000);
    write_mem64(64'h1008, 64'h3FF0000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_subf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'h4000000000000000, cpu.reg_file.registers[4], 35);

    // mulf: 2.0 * 3.0 = 6.0
    do_reset();
    write_mem64(64'h1000, 64'h4000000000000000);
    write_mem64(64'h1008, 64'h4008000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_mulf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'h4018000000000000, cpu.reg_file.registers[4], 36);

    // divf: 1.0 / 2.0 = 0.5
    do_reset();
    write_mem64(64'h1000, 64'h3FF0000000000000);
    write_mem64(64'h1008, 64'h4000000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_divf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    $display("  divf 1.0/2.0: got=0x%016h exp=0x3FE0000000000000 sign=%b exp=0x%03h mant=0x%013h",
             cpu.reg_file.registers[4],
             cpu.reg_file.registers[4][63],
             cpu.reg_file.registers[4][62:52],
             cpu.reg_file.registers[4][51:0]);
    check_reg(64'h3FE0000000000000, cpu.reg_file.registers[4], 37);

    $display("\n--- results: %0d passed, %0d failed ---", pass_count, fail_count);
    $finish;
  end

endmodule