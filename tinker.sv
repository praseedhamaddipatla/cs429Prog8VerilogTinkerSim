`define MEM_SIZE (512 * 1024)
`define PC_START 64'h2000

`include "hdl/alu.sv"
`include "hdl/regfile.sv"
`include "hdl/decoder.sv"

// instr fetch & pc control
module fetch (
    input clk,
    input reset,
    input halt,

    // decoded instr type
    input is_jump,
    input is_branch,
    input is_brgt,
    input is_brr_reg,
    input is_brr_imm,
    input is_return,
    input is_call,

    // branch condition from ALU (1 = taken)
    input branch_cond,

    // register values for target computation from regfile
    input [63:0] data1,  // raddr1 valu
    input [63:0] data2,  // raddr2 value

    // immediate from decoder
    input [63:0] immediate,

    // return address popped from stack
    input [63:0] mem_rdata,

    output [63:0] pc
);
  reg [63:0] pc_reg;
  assign pc = pc_reg;

  // branch is taken if ALU says so (brnz/brgt) or if unconditional
  wire taken = (is_branch && branch_cond) || is_jump;

  // next PC mux
  wire [63:0] next_pc = is_return ? mem_rdata :
  is_brr_imm ? (pc_reg + immediate) :
  is_brr_reg ? (pc_reg + data1) :
  is_branch ? (is_brgt ? data1 : data2) :
  data1;

  always @(posedge clk) begin
    if (reset) begin
      pc_reg <= `PC_START;
    end else if (!halt) begin
      if (taken) begin
        if (next_pc >= `MEM_SIZE) pc_reg <= `PC_START;
        else pc_reg <= next_pc;
      end else begin
        if (pc_reg + 64'd4 >= `MEM_SIZE) pc_reg <= `PC_START;
        else pc_reg <= pc_reg + 64'd4;
      end
    end
  end
endmodule

module mem_module #(
    parameter MEM_SIZE = 512 * 1024
) (
    input clk,
    input [63:0] fetch_addr,
    output [31:0] instr_out,
    input [63:0] data_addr,
    input [63:0] write_data,
    input we,
    output [63:0] read_data
);

  //actual mem
  reg [7:0] bytes[0:MEM_SIZE-1];

  //instr fetch port
  assign instr_out = {
    bytes[fetch_addr+3], bytes[fetch_addr+2], bytes[fetch_addr+1], bytes[fetch_addr]
  };
  assign read_data = {
    bytes[data_addr+7],
    bytes[data_addr+6],
    bytes[data_addr+5],
    bytes[data_addr+4],
    bytes[data_addr+3],
    bytes[data_addr+2],
    bytes[data_addr+1],
    bytes[data_addr]
  };

  //load/store port
  always @(posedge clk) begin
    if (we) begin
      bytes[data_addr]   <= write_data[7:0];
      bytes[data_addr+1] <= write_data[15:8];
      bytes[data_addr+2] <= write_data[23:16];
      bytes[data_addr+3] <= write_data[31:24];
      bytes[data_addr+4] <= write_data[39:32];
      bytes[data_addr+5] <= write_data[47:40];
      bytes[data_addr+6] <= write_data[55:48];
      bytes[data_addr+7] <= write_data[63:56];
    end
  end
endmodule


module tinker_core (
    input clk,
    input reset
);
  localparam MEM_SIZE = 512 * 1024;

  // wires to connect modules

  // IF → decoder
  wire [63:0] pc;
  wire [31:0] instr;

  // decoder outputs
  wire [4:0] raddr1, raddr2, waddr;
  wire [63:0] immediate;
  wire [ 4:0] op;
  wire use_imm, write;
  wire is_load, is_store;
  wire is_branch, is_brgt, is_jump;
  wire is_brr_reg, is_brr_imm;
  wire is_return, is_call;
  wire is_halt;
  wire is_mov_reg, is_mov_imm;
  wire [4:0] rt_addr;

  // regfile → ALU/IF/mem
  wire [63:0] data1, data2;

  // ALU → refile/IF
  wire [63:0] alu_result;

  // mem → regfile/IF
  wire [63:0] mem_rdata;

  // regfile writeback data
  wire [63:0] wb_data;

  // mem ctrl
  wire [63:0] mem_data_addr;
  wire [63:0] mem_write_val;
  wire        mem_we;

  // halt latch
  reg         halted;
  always @(posedge clk) begin
    if (reset) halted <= 0;
    else if (is_halt) halted <= 1;
  end

  // brgt / stack
  wire [63:0] rt_val = reg_file.registers[rt_addr];
  // call/return use r31 as stack pointer
  wire [63:0] r31_val = reg_file.registers[31];
  wire [63:0] stack_top = r31_val - 64'd8;

  // ALU input mux
  wire [63:0] alu_a = is_brgt ? data2 : data1;
  wire [63:0] alu_b = is_brgt ? rt_val : (use_imm ? immediate : data2);

  // mem ctrl
  assign mem_data_addr = (is_return || is_call) ? stack_top : (data1 + immediate);
  assign mem_write_val = is_call ? (pc + 64'd4) : data2;
  assign mem_we = (is_store || is_call) && !halted;

  // writeback mux
  assign wb_data =
      is_load    ? mem_rdata :
      is_mov_reg ? data1     :
      is_mov_imm ? ((data1 & ~64'hFFF) | immediate) :
                   alu_result;

  // module instantiation

  // pc logic
  fetch fetch_inst (
      .clk        (clk),
      .reset      (reset),
      .halt       (halted),
      .is_jump    (is_jump && !halted),
      .is_branch  (is_branch && !halted),
      .is_brgt    (is_brgt),
      .is_brr_reg (is_brr_reg),
      .is_brr_imm (is_brr_imm),
      .is_return  (is_return),
      .is_call    (is_call),
      .branch_cond(alu_result[0]),         // from ALU
      .data1      (data1),                 // from regfile
      .data2      (data2),                 // from reg file
      .immediate  (immediate),
      .mem_rdata  (mem_rdata),             // from mem
      .pc         (pc)
  );

  // memory: IF port + data port
  mem_module #(
      .MEM_SIZE(MEM_SIZE)
  ) memory (
      .clk(clk),
      .fetch_addr(pc),
      .instr_out(instr),
      .data_addr(mem_data_addr),
      .write_data(mem_write_val),
      .we(mem_we),
      .read_data(mem_rdata)
  );

  // IF → decoder
  decoder dec_inst (
      .instr(instr),
      .raddr1(raddr1),
      .raddr2(raddr2),
      .waddr(waddr),
      .immediate(immediate),
      .op(op),
      .use_imm(use_imm),
      .write(write),
      .is_load(is_load),
      .is_store(is_store),
      .is_branch(is_branch),
      .is_brgt(is_brgt),
      .is_jump(is_jump),
      .is_brr_reg(is_brr_reg),
      .is_brr_imm(is_brr_imm),
      .is_return(is_return),
      .is_call(is_call),
      .is_halt(is_halt),
      .is_mov_reg(is_mov_reg),
      .is_mov_imm(is_mov_imm),
      .rt_addr(rt_addr)
  );

  // decoder → regfile → ALU/IF
  reg_file reg_file (
      .clk(clk),
      .reset(reset),
      .raddr1(raddr1),
      .raddr2(raddr2),
      .waddr(waddr),
      .data(wb_data),
      .write(write && !halted),
      .r1(data1),
      .r2(data2)
  );

  // regfile → ALU → IF/regfile/mem
  alu alu_inst (
      .a(alu_a),
      .b(alu_b),
      .op(op),
      .result(alu_result)
  );

  // r31 initialized to top of memory on reset
  always @(posedge clk) begin
    if (reset) reg_file.registers[31] <= MEM_SIZE;
  end

endmodule
