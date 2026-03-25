module testbench;

reg clk;
reg reset;

tinker_core cpu(.clk(clk), .reset(reset));

always #5 clk = ~clk;

integer pass_count;
integer fail_count;

// instruction encoding helpers
// format: opcode[31:27] rd[26:22] rs[21:17] rt[16:12] imm[11:0]

function [31:0] make_add;
    input [4:0] rd, rs, rt;
    begin make_add = (5'h18 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_addi;
    input [4:0] rd;
    input [11:0] imm;
    begin make_addi = (5'h19 << 27) | (rd << 22) | imm; end
endfunction

function [31:0] make_sub;
    input [4:0] rd, rs, rt;
    begin make_sub = (5'h1A << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_subi;
    input [4:0] rd;
    input [11:0] imm;
    begin make_subi = (5'h1B << 27) | (rd << 22) | imm; end
endfunction

function [31:0] make_mul;
    input [4:0] rd, rs, rt;
    begin make_mul = (5'h1C << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_div;
    input [4:0] rd, rs, rt;
    begin make_div = (5'h1D << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_and;
    input [4:0] rd, rs, rt;
    begin make_and = (5'h00 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_or;
    input [4:0] rd, rs, rt;
    begin make_or = (5'h01 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_xor;
    input [4:0] rd, rs, rt;
    begin make_xor = (5'h02 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_not;
    input [4:0] rd, rs;
    begin make_not = (5'h03 << 27) | (rd << 22) | (rs << 17); end
endfunction

function [31:0] make_shftr;
    input [4:0] rd, rs, rt;
    begin make_shftr = (5'h04 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_shftri;
    input [4:0] rd;
    input [11:0] imm;
    begin make_shftri = (5'h05 << 27) | (rd << 22) | imm; end
endfunction

function [31:0] make_shftl;
    input [4:0] rd, rs, rt;
    begin make_shftl = (5'h06 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_shftli;
    input [4:0] rd;
    input [11:0] imm;
    begin make_shftli = (5'h07 << 27) | (rd << 22) | imm; end
endfunction

function [31:0] make_br;
    input [4:0] rd;
    begin make_br = (5'h08 << 27) | (rd << 22); end
endfunction

function [31:0] make_brr_imm;
    input [11:0] imm;
    begin make_brr_imm = (5'h0A << 27) | imm; end
endfunction

function [31:0] make_brnz;
    input [4:0] rd, rs;
    begin make_brnz = (5'h0B << 27) | (rd << 22) | (rs << 17); end
endfunction

function [31:0] make_call;
    input [4:0] rd;
    begin make_call = (5'h0C << 27) | (rd << 22); end
endfunction

function [31:0] make_return;
    begin make_return = (5'h0D << 27); end
endfunction

function [31:0] make_brgt;
    input [4:0] rd, rs, rt;
    begin make_brgt = (5'h0E << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_halt;
    begin make_halt = (5'h0F << 27); end
endfunction

function [31:0] make_load;
    input [4:0] rd, rs;
    input [11:0] imm;
    begin make_load = (5'h10 << 27) | (rd << 22) | (rs << 17) | imm; end
endfunction

function [31:0] make_mov_reg;
    input [4:0] rd, rs;
    begin make_mov_reg = (5'h11 << 27) | (rd << 22) | (rs << 17); end
endfunction

function [31:0] make_mov_imm;
    input [4:0] rd;
    input [11:0] imm;
    begin make_mov_imm = (5'h12 << 27) | (rd << 22) | imm; end
endfunction

function [31:0] make_store;
    input [4:0] rd, rs;
    input [11:0] imm;
    begin make_store = (5'h13 << 27) | (rd << 22) | (rs << 17) | imm; end
endfunction

function [31:0] make_addf;
    input [4:0] rd, rs, rt;
    begin make_addf = (5'h14 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_subf;
    input [4:0] rd, rs, rt;
    begin make_subf = (5'h15 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_mulf;
    input [4:0] rd, rs, rt;
    begin make_mulf = (5'h16 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
endfunction

function [31:0] make_divf;
    input [4:0] rd, rs, rt;
    begin make_divf = (5'h17 << 27) | (rd << 22) | (rs << 17) | (rt << 12); end
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
            $display("  FAIL [%0d]: got 0x%016h  expected 0x%016h",
                     test_id, got, expected);
            fail_count = fail_count + 1;
        end
    end
endtask

// pulse reset and clear the program area so tests don't bleed into each other
task do_reset;
    integer j;
    begin
        reset = 1;
        for (j = 0; j < 512; j = j + 1)
            cpu.memory.bytes[64'h2000 + j] = 8'h00;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
    end
endtask

task run_cycles;
    input integer n;
    integer j;
    begin
        for (j = 0; j < n; j = j + 1)
            @(posedge clk);
    end
endtask

// load a full 64-bit address into a register using two addi:
// first addi sets the lower 12 bits, second adds the upper part
// only works cleanly when addr fits in ~24 bits (fine for our test addresses)
// we use r29/r30 as scratch when building branch targets
task load_addr;
    input [4:0]  rd;
    input [63:0] addr;
    input [63:0] at;   // where to write these two instructions
    begin
        // write:  addi rd, lower12(addr)   then   addi rd, upper bits
        // addr like 0x2018: lower = 0x018, upper = 0x2000
        // but 0x2000 > 12 bits so we split differently:
        // addi rd, (addr & 0xFFF)  then addi rd, (addr >> 12) << 12
        // since addi sign-extends, we just do two addis with 12-bit chunks
        write_instr(at,    make_addi(rd, addr[11:0]));
        write_instr(at+4,  make_addi(rd, addr[23:12]));  // adds upper 12 bits (shifted by 12 already via repeated addi)
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

    // ----------------------------------------------------------------
    // reset state
    // ----------------------------------------------------------------
    $display("\n--- reset state ---");
    @(posedge clk);
    @(posedge clk);
    reset = 0;

    // r0-r30 should be zero
    begin
        integer all_zero;
        all_zero = 1;
        for (i = 0; i < 31; i = i + 1)
            if (cpu.reg_file.registers[i] !== 64'd0)
                all_zero = 0;
        if (all_zero) begin
            $display("  pass [0]: r0-r30 all zero");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [0]: some register not zero after reset");
            fail_count = fail_count + 1;
        end
    end

    // r31 should be 512*1024 = 524288
    check_reg(64'd524288, cpu.reg_file.registers[31], 1);

    // ----------------------------------------------------------------
    // integer arithmetic
    // ----------------------------------------------------------------
    $display("\n--- integer arithmetic ---");

    // add: 20 + 30 = 50
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd20));
    write_instr(64'h2004, make_addi(5'd2, 12'd30));
    write_instr(64'h2008, make_add(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd50, cpu.reg_file.registers[3], 2);

    // addi with negative immediate: 10 + (-3) = 7
    // 0xFFD is -3 in 12-bit two's complement
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd10));
    write_instr(64'h2004, make_addi(5'd1, 12'hFFD));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd7, cpu.reg_file.registers[1], 3);

    // sub: 100 - 40 = 60
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd100));
    write_instr(64'h2004, make_addi(5'd2, 12'd40));
    write_instr(64'h2008, make_sub(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd60, cpu.reg_file.registers[3], 4);

    // subi: 50 - 7 = 43
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd50));
    write_instr(64'h2004, make_subi(5'd1, 12'd7));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd43, cpu.reg_file.registers[1], 5);

    // mul: 6 * 7 = 42
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd6));
    write_instr(64'h2004, make_addi(5'd2, 12'd7));
    write_instr(64'h2008, make_mul(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd42, cpu.reg_file.registers[3], 6);

    // div: 100 / 4 = 25
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd100));
    write_instr(64'h2004, make_addi(5'd2, 12'd4));
    write_instr(64'h2008, make_div(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd25, cpu.reg_file.registers[3], 7);

    // sub wrapping negative: 5 - 10 = -5 (0xFFFFFFFFFFFFFFFB)
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd5));
    write_instr(64'h2004, make_addi(5'd2, 12'd10));
    write_instr(64'h2008, make_sub(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'hFFFFFFFFFFFFFFFB, cpu.reg_file.registers[3], 8);

    // mul by zero
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd99));
    write_instr(64'h2004, make_addi(5'd2, 12'd0));
    write_instr(64'h2008, make_mul(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd0, cpu.reg_file.registers[3], 9);

    // ----------------------------------------------------------------
    // logic
    // ----------------------------------------------------------------
    $display("\n--- logic ---");

    // and: 0xF0 & 0xFF = 0xF0
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'hF0));
    write_instr(64'h2004, make_addi(5'd2, 12'hFF));
    write_instr(64'h2008, make_and(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'hF0, cpu.reg_file.registers[3], 10);

    // or: 0xF0 | 0x0F = 0xFF
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'hF0));
    write_instr(64'h2004, make_addi(5'd2, 12'h0F));
    write_instr(64'h2008, make_or(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'hFF, cpu.reg_file.registers[3], 11);

    // xor: 0xFF ^ 0x0F = 0xF0
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'hFF));
    write_instr(64'h2004, make_addi(5'd2, 12'h0F));
    write_instr(64'h2008, make_xor(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'hF0, cpu.reg_file.registers[3], 12);

    // not: ~0 = all ones
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd0));
    write_instr(64'h2004, make_not(5'd2, 5'd1));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'hFFFFFFFFFFFFFFFF, cpu.reg_file.registers[2], 13);

    // and with zero: anything & 0 = 0
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'hFFF));
    write_instr(64'h2004, make_addi(5'd2, 12'd0));
    write_instr(64'h2008, make_and(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd0, cpu.reg_file.registers[3], 14);

    // or with all-ones: anything | ~0 = ~0
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd0));
    write_instr(64'h2004, make_not(5'd2, 5'd1));           // r2 = ~0
    write_instr(64'h2008, make_addi(5'd3, 12'hABC));
    write_instr(64'h200C, make_or(5'd4, 5'd3, 5'd2));
    write_instr(64'h2010, make_halt());
    run_cycles(10);
    check_reg(64'hFFFFFFFFFFFFFFFF, cpu.reg_file.registers[4], 15);

    // ----------------------------------------------------------------
    // shifts
    // ----------------------------------------------------------------
    $display("\n--- shifts ---");

    // shftri: 0x80 >> 3 = 0x10
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'h80));
    write_instr(64'h2004, make_shftri(5'd1, 12'd3));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'h10, cpu.reg_file.registers[1], 16);

    // shftli: 1 << 8 = 256
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd8));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd256, cpu.reg_file.registers[1], 17);

    // shftr register: 0x40 >> 2 = 0x10
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'h40));
    write_instr(64'h2004, make_addi(5'd2, 12'd2));
    write_instr(64'h2008, make_shftr(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'h10, cpu.reg_file.registers[3], 18);

    // shftl register: 1 << 4 = 16
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd1));
    write_instr(64'h2004, make_addi(5'd2, 12'd4));
    write_instr(64'h2008, make_shftl(5'd3, 5'd1, 5'd2));
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd16, cpu.reg_file.registers[3], 19);

    // shift by zero: value unchanged
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd42));
    write_instr(64'h2004, make_shftri(5'd1, 12'd0));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd42, cpu.reg_file.registers[1], 20);

    // ----------------------------------------------------------------
    // data movement
    // ----------------------------------------------------------------
    $display("\n--- data movement ---");

    // mov reg: r2 = r1
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd99));
    write_instr(64'h2004, make_mov_reg(5'd2, 5'd1));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'd99, cpu.reg_file.registers[2], 21);

    // mov imm: sets lower 12 bits, r1 starts at 0 so result is just 0xABC
    do_reset();
    write_instr(64'h2000, make_mov_imm(5'd1, 12'hABC));
    write_instr(64'h2004, make_halt());
    run_cycles(5);
    check_reg(64'hABC, cpu.reg_file.registers[1], 22);

    // mov imm preserves upper bits:
    // addi with 0xFFF sign-extends to 0xFFFFFFFFFFFFFFFF, then mov imm replaces lower 12 with 0x123
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'hFFF));
    write_instr(64'h2004, make_mov_imm(5'd1, 12'h123));
    write_instr(64'h2008, make_halt());
    run_cycles(6);
    check_reg(64'hFFFFFFFFFFFFF123, cpu.reg_file.registers[1], 23);

    // store then load at offset 0
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'h100));        // r1 = base addr 0x100
    write_instr(64'h2004, make_addi(5'd2, 12'd55));
    write_instr(64'h2008, make_store(5'd1, 5'd2, 12'd0));   // mem[0x100] = 55
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd0));    // r3 = mem[0x100]
    write_instr(64'h2010, make_halt());
    run_cycles(10);
    check_reg(64'd55, cpu.reg_file.registers[3], 24);

    // store then load at nonzero offset
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'h100));
    write_instr(64'h2004, make_addi(5'd2, 12'd42));
    write_instr(64'h2008, make_store(5'd1, 5'd2, 12'd8));   // mem[0x108] = 42
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));    // r3 = mem[0x108]
    write_instr(64'h2010, make_halt());
    run_cycles(10);
    check_reg(64'd42, cpu.reg_file.registers[3], 25);

    // store overwrites: write 11 then write 99 to same address, load should give 99
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'h100));
    write_instr(64'h2004, make_addi(5'd2, 12'd11));
    write_instr(64'h2008, make_store(5'd1, 5'd2, 12'd0));
    write_instr(64'h200C, make_addi(5'd2, 12'd88));         // r2 = 11+88 = 99... actually addi adds to rd so r2 = 11+88=99
    write_instr(64'h2010, make_store(5'd1, 5'd2, 12'd0));   // overwrite with 99
    write_instr(64'h2014, make_load(5'd3, 5'd1, 12'd0));
    write_instr(64'h2018, make_halt());
    run_cycles(14);
    check_reg(64'd99, cpu.reg_file.registers[3], 26);

    // ----------------------------------------------------------------
    // control flow
    // ----------------------------------------------------------------
    $display("\n--- control flow ---");

    // br: set r4 = 0x2010, jump to it, skip an addi, verify r1 not modified
    // we build 0x2010 as: addi r4, 0x10 (lower 12) then addi r4, 0x2000
    // but 0x2000 = 8192 which doesn't fit in 12 bits (max 4095 unsigned, or -2048 to 2047 signed)
    // so instead we build it as: addi r4, 0x10 then shftli r5,1,13 then add r4,r4,r5
    // simpler: just place halt close enough that 12-bit offset works
    // use addi twice: r4 = 0 + 16 = 0x10, then since we need 0x2010 use a different approach:
    // preload 0x2000 into r5 via shifting: addi r5,1 then shftli r5,13 gives 0x2000, add r4+r5
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd0));          // r1 = 0 (sentinel)
    write_instr(64'h2004, make_addi(5'd4, 12'h10));         // r4 = 0x10
    write_instr(64'h2008, make_addi(5'd5, 12'd1));          // r5 = 1
    write_instr(64'h200C, make_shftli(5'd5, 12'd13));       // r5 = 1<<13 = 0x2000
    write_instr(64'h2010, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x10 + 0x2000 = 0x2010
    write_instr(64'h2014, make_br(5'd4));                   // jump to 0x2014+4=skip next... wait, r4=0x2010+0x2004? no r4=0x2010
    // actually: br jumps to 0x2010, but we're executing from 0x2014, so r4 must be the target
    // r4 = 0x2018 to skip the addi at 0x2018, let's recalculate:
    // instructions at: 2000,2004,2008,200C,2010,2014 = br, 2018 = addi(bad), 201C = halt
    // so we need r4 = 0x201C
    // redo: r4 = 0x1C + 0x2000 = 0x201C
    // overwrite:
    write_instr(64'h2004, make_addi(5'd4, 12'h1C));         // r4 = 0x1C
    write_instr(64'h2010, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x1C + 0x2000 = 0x201C
    write_instr(64'h2014, make_br(5'd4));                   // jump to 0x201C
    write_instr(64'h2018, make_addi(5'd1, 12'd99));         // should be skipped
    write_instr(64'h201C, make_halt());
    run_cycles(16);
    check_reg(64'd0, cpu.reg_file.registers[1], 27);

    // brnz taken: rs=1 nonzero so jump, skip the bad addi
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd1));          // r1 = 1 (test value, nonzero)
    write_instr(64'h2004, make_addi(5'd2, 12'd0));          // r2 = 0 (sentinel)
    write_instr(64'h2008, make_addi(5'd5, 12'd1));
    write_instr(64'h200C, make_shftli(5'd5, 12'd13));       // r5 = 0x2000
    write_instr(64'h2010, make_addi(5'd4, 12'h20));         // r4 = 0x1C
    write_instr(64'h2014, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x201C
    write_instr(64'h2018, make_brnz(5'd4, 5'd1));           // if r1!=0: jump to r4
    write_instr(64'h201C, make_addi(5'd2, 12'd99));         // should be skipped
    write_instr(64'h2020, make_halt());
    run_cycles(18);
    check_reg(64'd0, cpu.reg_file.registers[2], 28);

    // brnz not taken: rs=0 so no jump, the addi executes
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd0));          // r1 = 0 (branch not taken)
    write_instr(64'h2004, make_addi(5'd2, 12'd0));
    write_instr(64'h2008, make_addi(5'd5, 12'd1));
    write_instr(64'h200C, make_shftli(5'd5, 12'd13));
    write_instr(64'h2010, make_addi(5'd4, 12'h1C));
    write_instr(64'h2014, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x201C (far target)
    write_instr(64'h2018, make_brnz(5'd4, 5'd1));           // r1==0, not taken
    write_instr(64'h201C, make_addi(5'd2, 12'd55));         // should execute
    write_instr(64'h2020, make_halt());
    run_cycles(18);
    check_reg(64'd55, cpu.reg_file.registers[2], 29);

    // brgt taken: r1=10 > r2=3
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd10));
    write_instr(64'h2004, make_addi(5'd2, 12'd3));
    write_instr(64'h2008, make_addi(5'd6, 12'd0));          // r6 = sentinel
    write_instr(64'h200C, make_addi(5'd5, 12'd1));
    write_instr(64'h2010, make_shftli(5'd5, 12'd13));
    write_instr(64'h2014, make_addi(5'd4, 12'h24));
    write_instr(64'h2018, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x2024
    write_instr(64'h201C, make_brgt(5'd4, 5'd1, 5'd2));     // r1>r2, jump to 0x2024
    write_instr(64'h2020, make_addi(5'd6, 12'd99));         // should be skipped
    write_instr(64'h2024, make_halt());
    run_cycles(18);
    check_reg(64'd0, cpu.reg_file.registers[6], 30);

    // brgt not taken: r1=3 not > r2=10
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd3));
    write_instr(64'h2004, make_addi(5'd2, 12'd10));
    write_instr(64'h2008, make_addi(5'd6, 12'd0));
    write_instr(64'h200C, make_addi(5'd5, 12'd1));
    write_instr(64'h2010, make_shftli(5'd5, 12'd13));
    write_instr(64'h2014, make_addi(5'd4, 12'h24));
    write_instr(64'h2018, make_add(5'd4, 5'd4, 5'd5));
    write_instr(64'h201C, make_brgt(5'd4, 5'd1, 5'd2));     // not taken
    write_instr(64'h2020, make_addi(5'd6, 12'd77));         // should execute
    write_instr(64'h2024, make_halt());
    run_cycles(18);
    check_reg(64'd77, cpu.reg_file.registers[6], 31);

    // brr_imm forward: skip one instruction
    do_reset();
    write_instr(64'h2000, make_addi(5'd1, 12'd0));
    write_instr(64'h2004, make_brr_imm(12'd8));             // pc = 0x2004 + 8 = 0x200C
    write_instr(64'h2008, make_addi(5'd1, 12'd99));         // skipped
    write_instr(64'h200C, make_halt());
    run_cycles(8);
    check_reg(64'd0, cpu.reg_file.registers[1], 32);

    // call and return: subroutine sets r1=42 then returns
    do_reset();
    write_instr(64'h2000, make_addi(5'd5, 12'd1));
    write_instr(64'h2004, make_shftli(5'd5, 12'd13));       // r5 = 0x2000
    write_instr(64'h2008, make_addi(5'd4, 12'h18));
    write_instr(64'h200C, make_add(5'd4, 5'd4, 5'd5));      // r4 = 0x2018 (subroutine addr)
    write_instr(64'h2010, make_call(5'd4));                  // call, saves 0x2014 to stack
    write_instr(64'h2014, make_halt());                      // return lands here
    // subroutine at 0x2018:
    write_instr(64'h2018, make_addi(5'd1, 12'd42));
    write_instr(64'h201C, make_return());
    run_cycles(20);
    check_reg(64'd42, cpu.reg_file.registers[1], 33);

    // ----------------------------------------------------------------
    // floating point
    // ----------------------------------------------------------------
    $display("\n--- floating point ---");
    // ieee 754 double bit patterns used:
    //  1.0 = 0x3FF0000000000000
    //  2.0 = 0x4000000000000000
    //  3.0 = 0x4008000000000000
    //  6.0 = 0x4018000000000000
    //  0.5 = 0x3FE0000000000000
    // -1.0 = 0xBFF0000000000000
    // -2.0 = 0xC000000000000000
    // we write the bit patterns into data memory then load them into registers

    // addf: 1.0 + 2.0 = 3.0
    do_reset();
    write_mem64(64'h1000, 64'h3FF0000000000000);
    write_mem64(64'h1008, 64'h4000000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));       // r1 = 0x1000
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));    // r2 = 1.0
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));    // r3 = 2.0
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
    check_reg(64'h3FE0000000000000, cpu.reg_file.registers[4], 37);

    // addf with negative: 1.0 + (-1.0) = 0.0
    do_reset();
    write_mem64(64'h1000, 64'h3FF0000000000000);
    write_mem64(64'h1008, 64'hBFF0000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_addf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'h0000000000000000, cpu.reg_file.registers[4], 38);

    // subf going negative: 1.0 - 2.0 = -1.0
    do_reset();
    write_mem64(64'h1000, 64'h3FF0000000000000);
    write_mem64(64'h1008, 64'h4000000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_subf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'hBFF0000000000000, cpu.reg_file.registers[4], 39);

    // mulf with negative: (-1.0) * 2.0 = -2.0
    do_reset();
    write_mem64(64'h1000, 64'hBFF0000000000000);
    write_mem64(64'h1008, 64'h4000000000000000);
    write_instr(64'h2000, make_addi(5'd1, 12'h1));
    write_instr(64'h2004, make_shftli(5'd1, 12'd12));
    write_instr(64'h2008, make_load(5'd2, 5'd1, 12'd0));
    write_instr(64'h200C, make_load(5'd3, 5'd1, 12'd8));
    write_instr(64'h2010, make_mulf(5'd4, 5'd2, 5'd3));
    write_instr(64'h2014, make_halt());
    run_cycles(14);
    check_reg(64'hC000000000000000, cpu.reg_file.registers[4], 40);

    // ----------------------------------------------------------------
    // summary
    // ----------------------------------------------------------------
    $display("\n--- results: %0d passed, %0d failed ---", pass_count, fail_count);
    $finish;
end

endmodule