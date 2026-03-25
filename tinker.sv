`define MEM_SIZE (512 * 1024)
`define PC_START 64'h2000

// fetch module - owns pc
// pc updates on the rising edge after current instr finishes
module fetch (
    input clk,
    input reset,
    input halt,
    input branch_taken,
    input [63:0] next_pc,
    output [63:0] pc
);

  reg [63:0] pc_reg;
  assign pc = pc_reg;

  always @(posedge clk) begin
    if (reset) pc_reg <= `PC_START;
    else if (!halt) begin
      if (branch_taken) pc_reg <= next_pc;
      else pc_reg <= pc_reg + 64'd4;
    end
  end

endmodule


// memory module
// has two ports: one for instr fetch and one for data load/store
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

  reg [7:0] bytes[0:MEM_SIZE-1];

  // little-endian
  assign instr_out = {
    bytes[fetch_addr+3], bytes[fetch_addr+2], bytes[fetch_addr+1], bytes[fetch_addr]
  };

  // same layout for 64-bit data reads
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


// top-level core - wires fetch, memory, decoder, register file, and alu together
module tinker_core (
    input clk,
    input reset
);

  localparam MEM_SIZE = 512 * 1024;

  // interconnect wires
  wire [63:0] pc;
  wire [31:0] instr;

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
  wire is_priv;
  wire [11:0] priv_L;
  wire [4:0] rt_addr;

  wire [63:0] data1, data2;
  wire [63:0] alu_result;
  wire [63:0] mem_rdata;

  // halt latch - once set we stop fetching and writing
  reg halted;

  always @(posedge clk) begin
    if (reset) halted <= 0;
    else if (is_halt) halted <= 1;
  end

  // brgt needs a third register read; use array directly
  wire [63:0] rt_val = reg_file.registers[rt_addr];

  // brnz
  wire brnz_taken = is_branch && !is_brgt && (data2 != 64'd0);

  // brgt
  wire brgt_taken = is_branch && is_brgt && ($signed(data2) > $signed(rt_val));

  wire branch_taken_any = brnz_taken || brgt_taken || is_jump;

  // next pc mux - selects the correct target for each jump/branch type
  wire [63:0] next_pc_val;
  // handle branch cases
  assign next_pc_val = is_return ? mem_rdata :
      is_brr_imm ? (pc + immediate) :
      is_brr_reg ? (pc + data1) :
      data1;

  // return and call  use mem[r31-8]
  wire [63:0] r31_val = reg_file.registers[31];
  wire [63:0] stack_top = r31_val - 64'd8;

  // handle return
  wire [63:0] mem_data_addr = (is_return || is_call) ? stack_top : (data1 + immediate);

  // handle call
  wire [63:0] mem_write_val = is_call ? (pc + 64'd4) : data2;
  wire [63:0] mem_store_addr = is_call ? stack_top : (data1 + immediate);

  wire mem_we = (is_store || is_call) && !halted;

  // write-back mux
  wire [63:0] wb_data;
  assign wb_data = is_load ? mem_rdata : is_mov_reg ? data1 :
      // mov rd, L
      is_mov_imm ? ((data1 & ~64'hFFF) | immediate) : alu_result;

  // submodule instantiations

  fetch fetch_inst (
      .clk(clk),
      .reset(reset),
      .halt(halted),
      .branch_taken(branch_taken_any && !halted),
      .next_pc(next_pc_val),
      .pc(pc)
  );

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
      .is_priv(is_priv),
      .priv_L(priv_L),
      .rt_addr(rt_addr)
  );

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

  alu alu_inst (
      .a(data1),
      .b(use_imm ? immediate : data2),
      .op(op),
      .result(alu_result)
  );

  // start at the top of memory
  // overwrite r31 here on the same edge
  always @(posedge clk) begin
    if (reset) reg_file.registers[31] <= MEM_SIZE;
  end

endmodule
