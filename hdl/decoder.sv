module decoder (
    input [31:0] instr,
    output reg [4:0] raddr1,
    output reg [4:0] raddr2,
    output reg [4:0] waddr,
    output reg [63:0] immediate,
    output reg [4:0] op,
    output reg use_imm,
    output reg write,
    output reg is_load,
    output reg is_store,
    output reg is_branch,   // brnz, brgt
    output reg is_brgt,     // brgt needs a third reg
    output reg is_jump,     // br, brr, call, return
    output reg is_brr_reg,  // brr rd: pc = pc + rd
    output reg is_brr_imm,  // brr L:  pc = pc + L
    output reg is_return,   // return: pc = mem[r31-8]
    output reg is_call,     // call
    output reg is_halt,
    output reg is_mov_reg,  // mov rd, rs
    output reg is_mov_imm,  // mov rd, L
    output reg is_priv,
    output reg [11:0] priv_L,
    output reg [4:0] rt_addr  // third reg for brgt
);

  // get fields
  wire [ 4:0] opcode = instr[31:27];
  wire [ 4:0] rd = instr[26:22];
  wire [ 4:0] rs = instr[21:17];
  wire [ 4:0] rt = instr[16:12];
  wire [11:0] imm12 = instr[11:0];

  // sign-extended immediate: if bit 11 is 1 the value is negative
  wire [63:0] imm_signed = {{52{imm12[11]}}, imm12};
  // zero-extended immediate: used for shifts and mov rd,L where L is always positive
  wire [63:0] imm_unsigned = {52'd0, imm12};

  // alu op selectors
  localparam ADD = 5'd0;
  localparam SUB = 5'd1;
  localparam MUL = 5'd2;
  localparam DIV = 5'd3;
  localparam AND = 5'd4;
  localparam OR = 5'd5;
  localparam XOR = 5'd6;
  localparam NOT = 5'd7;
  localparam SHR = 5'd8;
  localparam SHL = 5'd9;
  localparam ADDF = 5'd10;
  localparam SUBF = 5'd11;
  localparam MULF = 5'd12;
  localparam DIVF = 5'd13;

  always @(*) begin
    // default everything to zero/no-op
    raddr1     = 5'd0;
    raddr2     = 5'd0;
    waddr      = 5'd0;
    rt_addr    = 5'd0;
    immediate  = 64'd0;
    op         = ADD;
    use_imm    = 0;
    write      = 0;
    is_load    = 0;
    is_store   = 0;
    is_branch  = 0;
    is_brgt    = 0;
    is_jump    = 0;
    is_brr_reg = 0;
    is_brr_imm = 0;
    is_return  = 0;
    is_call    = 0;
    is_halt    = 0;
    is_mov_reg = 0;
    is_mov_imm = 0;
    is_priv    = 0;
    priv_L     = 12'd0;

    case (opcode)

      // logic
      5'h00: begin  // and rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = AND;
        write = 1;
      end
      5'h01: begin  // or rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = OR;
        write = 1;
      end
      5'h02: begin  // xor rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = XOR;
        write = 1;
      end
      5'h03: begin  // not rd, rs  (no rt)
        raddr1 = rs;
        waddr = rd;
        op = NOT;
        write = 1;
      end

      // shifts
      5'h04: begin  // shftr rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = SHR;
        write = 1;
      end
      5'h05: begin  // shftri rd, L  (shift amount can't be negative)
        raddr1 = rd;
        waddr = rd;
        immediate = imm_unsigned;
        op = SHR;
        use_imm = 1;
        write = 1;
      end
      5'h06: begin  // shftl rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = SHL;
        write = 1;
      end
      5'h07: begin  // shftli rd, L
        raddr1 = rd;
        waddr = rd;
        immediate = imm_unsigned;
        op = SHL;
        use_imm = 1;
        write = 1;
      end

      // control flow
      5'h08: begin  // br rd; jump to address in rd
        raddr1  = rd;
        is_jump = 1;
      end
      5'h09: begin  // brr rd; pc = pc + rd
        raddr1 = rd;
        is_jump = 1;
        is_brr_reg = 1;
      end
      5'h0A: begin  // brr L; pc = pc + L (signed offset)
        immediate = imm_signed;
        is_jump = 1;
        is_brr_imm = 1;
      end
      5'h0B: begin  // brnz rd, rs; if rs != 0: pc = rd
        raddr1 = rd;
        raddr2 = rs;
        is_branch = 1;
      end
      5'h0C: begin  // call rd; mem[r31-8] = pc+4, pc = rd
        raddr1  = rd;
        is_jump = 1;
        is_call = 1;
      end
      5'h0D: begin  // return; pc = mem[r31-8]
        is_jump   = 1;
        is_return = 1;
      end
      5'h0E: begin  // brgt rd, rs, rt; if rs > rt (signed): pc = rd
        raddr1 = rd;
        raddr2 = rs; 
        rt_addr = rt;
        is_branch = 1;
        is_brgt = 1;
      end

      // priv: L=0 halt, L=3 input, L=4 output
      5'h0F: begin
        raddr1  = rd;
        raddr2  = rs;
        waddr   = rd;
        is_priv = 1;
        priv_L  = imm12;
        if (imm12 == 12'd0) is_halt = 1;
        else if (imm12 == 12'd3) write = 1;  // input writes a value into rd
      end

      // data movement
      5'h10: begin  // mov rd, (rs)(L); load rd from mem
        // L is sign-extended
        raddr1 = rs;
        waddr = rd;
        immediate = imm_signed;
        is_load = 1;
        write = 1;
      end
      5'h11: begin  // mov rd, rs; register copy
        raddr1 = rs;
        waddr = rd;
        is_mov_reg = 1;
        write = 1;
      end
      5'h12: begin  // mov rd, L; set lower 12 bits of rd, upper 52 unchanged
        raddr1 = rd;
        waddr = rd;
        immediate = imm_unsigned;  // L is unsigned here
        is_mov_imm = 1;
        write = 1;
      end
      5'h13: begin  // mov (rd)(L), rs; store rs to memory
        raddr1 = rd;  // base address
        raddr2 = rs;  // value to store
        immediate = imm_signed;
        is_store = 1;
      end

      // floating point
      5'h14: begin  // addf rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = ADDF;
        write = 1;
      end
      5'h15: begin  // subf rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = SUBF;
        write = 1;
      end
      5'h16: begin  // mulf rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = MULF;
        write = 1;
      end
      5'h17: begin  // divf rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = DIVF;
        write = 1;
      end

      // integer arithmetic
      5'h18: begin  // add rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = ADD;
        write = 1;
      end
      5'h19: begin  // addi rd, L; rd = rd + L (signed)
        raddr1 = rd;
        waddr = rd;
        immediate = imm_signed;
        op = ADD;
        use_imm = 1;
        write = 1;
      end
      5'h1A: begin  // sub rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = SUB;
        write = 1;
      end
      5'h1B: begin  // subi rd, L; rd = rd - L (signed)
        raddr1 = rd;
        waddr = rd;
        immediate = imm_signed;
        op = SUB;
        use_imm = 1;
        write = 1;
      end
      5'h1C: begin  // mul rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = MUL;
        write = 1;
      end
      5'h1D: begin  // div rd, rs, rt
        raddr1 = rs;
        raddr2 = rt;
        waddr = rd;
        op = DIV;
        write = 1;
      end

      default: begin
      end
    endcase
  end

endmodule
