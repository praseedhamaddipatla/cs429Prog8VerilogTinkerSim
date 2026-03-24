module testbench;

  reg clk;
  reg reset;

  tinker_core cpu (
      .clk  (clk),
      .reset(reset)
  );

  always #5 clk = ~clk;

  // instruction encoding helpers
  // format: opcode[31:27] rd[26:22] rs[21:17] rt[16:12] imm[11:0]

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

  function [31:0] make_halt;
    begin
      make_halt = (5'h0F << 27) | 12'd0;  // priv with L=0 is halt
    end
  endfunction

  function [31:0] make_addf;
    input [4:0] rd, rs, rt;
    begin
      make_addf = (5'h14 << 27) | (rd << 22) | (rs << 17) | (rt << 12);
    end
  endfunction

  // write a 32-bit instruction into memory as 4 little-endian bytes
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

  // write a 64-bit value into memory as 8 little-endian bytes
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

  integer pass_count;
  integer fail_count;

  initial begin
    $dumpfile("sim/wave.vcd");
    $dumpvars(0, testbench);

    clk = 0;
    reset = 1;
    pass_count = 0;
    fail_count = 0;

    // load the program before releasing reset - program starts at 0x2000
    // test: r1 = 5, r2 = 10, r3 = r1 + r2 = 15
    write_instr(64'h2000, make_addi(5'd1, 12'd5));
    write_instr(64'h2004, make_addi(5'd2, 12'd10));
    write_instr(64'h2008, make_add(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());

    @(posedge clk);
    @(posedge clk);
    reset = 0;

    repeat (10) @(posedge clk);

    $display("--- integer add test ---");
    if (cpu.reg_file.registers[1] === 64'd5) begin
      $display("pass: r1 = %0d", cpu.reg_file.registers[1]);
      pass_count = pass_count + 1;
    end else begin
      $display("fail: r1 = %0d (expected 5)", cpu.reg_file.registers[1]);
      fail_count = fail_count + 1;
    end

    if (cpu.reg_file.registers[2] === 64'd10) begin
      $display("pass: r2 = %0d", cpu.reg_file.registers[2]);
      pass_count = pass_count + 1;
    end else begin
      $display("fail: r2 = %0d (expected 10)", cpu.reg_file.registers[2]);
      fail_count = fail_count + 1;
    end

    if (cpu.reg_file.registers[3] === 64'd15) begin
      $display("pass: r3 = %0d", cpu.reg_file.registers[3]);
      pass_count = pass_count + 1;
    end else begin
      $display("fail: r3 = %0d (expected 15)", cpu.reg_file.registers[3]);
      fail_count = fail_count + 1;
    end

    $display("--- reset state test ---");
    if (cpu.reg_file.registers[31] === (512 * 1024)) begin
      $display("pass: r31 = %0d", cpu.reg_file.registers[31]);
      pass_count = pass_count + 1;
    end else begin
      $display("fail: r31 = %0d (expected %0d)", cpu.reg_file.registers[31], 512 * 1024);
      fail_count = fail_count + 1;
    end

    $display("--- results: %0d passed, %0d failed ---", pass_count, fail_count);
    $finish;
  end

endmodule
