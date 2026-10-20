`timescale 1ns/1ps

// Execution datapath: memory lives outside this block.
// Controller enables load writeback only after a successful response has been captured.
module execution_datapath (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instr,
    input  logic [31:0] instr_pc,
    input  logic        execute_en,
    input  logic [31:0] load_data,
    output logic [31:0] alu_a,
    output logic [31:0] alu_b,
    output logic [31:0] result,
    output logic [4:0]  rd,
    output logic        write_en,
    output logic        illegal,
    output logic        is_load,
    output logic        is_memory,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [2:0]  mem_funct3,
    output logic        is_branch,
    output logic        branch_taken,
    output logic [31:0] branch_target,
    output logic        target_misaligned,
    output logic        is_jump,
    output logic [31:0] jump_target,
    output logic        jump_target_misaligned
);
    logic [4:0] a_rs1,a_rs2,a_rd,m_rs1,m_rs2,m_rd,rs1,rs2;
    logic [3:0] arithmetic_op,selected_op;
    logic arithmetic_write,arithmetic_imm,arithmetic_illegal,memory_illegal;
    logic [31:0] arithmetic_offset,offset,rdata2,alu_result;
    logic is_store;
    logic [4:0] b_rs1,b_rs2;
    logic [31:0] branch_offset;
    logic branch_illegal;
    logic [4:0] j_rs1,j_rd;
    logic [31:0] jump_offset,jump_link;
    logic jump_illegal;
    logic [4:0] u_rd;
    logic [31:0] upper_imm,upper_result;
    logic is_upper,upper_illegal;
    // Named internal signals are useful for the learning waveform.
        logic [31:0] effective_addr,store_data;

    decoder arithmetic_decode (
        .instr(instr),.rs1(a_rs1),.rs2(a_rs2),.rd(a_rd),.alu_op(arithmetic_op),
        .reg_write(arithmetic_write),.alu_src_imm(arithmetic_imm),
        .imm(arithmetic_offset),.illegal(arithmetic_illegal)
    );
    load_store_decode memory_decode (
        .instr(instr),.rs1(m_rs1),.rs2(m_rs2),.rd(m_rd),.offset(offset),
        .is_load(is_load),.is_store(is_store),.illegal(memory_illegal)
    );
    branch_unit branch_decode (
        .instr(instr),.instr_pc(instr_pc),.rs1_value(alu_a),.rs2_value(rdata2),
        .rs1(b_rs1),.rs2(b_rs2),.offset(branch_offset),.target(branch_target),
        .branch_taken(branch_taken),.target_misaligned(target_misaligned),.illegal(branch_illegal)
    );
    jump_unit jump_decode (
        .instr(instr),.instr_pc(instr_pc),.rs1_value(alu_a),.rs1(j_rs1),.rd(j_rd),
        .offset(jump_offset),.target(jump_target),.link_data(jump_link),.is_jump(is_jump),
        .target_misaligned(jump_target_misaligned),.illegal(jump_illegal)
    );
    upper_imm_unit upper_decode (
        .instr(instr),.instr_pc(instr_pc),.rd(u_rd),.imm(upper_imm),
        .result(upper_result),.is_upper(is_upper),.illegal(upper_illegal)
    );
    assign is_branch=!branch_illegal;
    assign is_memory=is_load || is_store;
    // Supported if any of the five decoders recognizes the instruction.
    assign illegal=arithmetic_illegal && memory_illegal && branch_illegal && jump_illegal && upper_illegal;
    assign rs1=is_upper ? 5'd0 : (is_jump ? j_rs1 : (is_branch ? b_rs1 : (is_memory ? m_rs1 : a_rs1)));
    assign rs2=(is_upper || is_jump) ? 5'd0 : (is_branch ? b_rs2 : (is_memory ? m_rs2 : a_rs2));
    assign rd=is_upper ? u_rd : (is_jump ? j_rd : (is_branch ? 5'd0 : (is_memory ? m_rd : a_rd)));
    assign selected_op=is_memory ? 4'd0 : arithmetic_op; // Address uses ADD.
    assign alu_b=is_memory ? offset : (arithmetic_imm ? arithmetic_offset : rdata2);
    assign effective_addr=alu_result;
    assign store_data=rdata2;
    assign mem_addr=effective_addr;
    assign mem_wdata=store_data;
    assign mem_funct3=instr[14:12];
    assign mem_write=is_store;
    assign result=is_upper ? upper_result : (is_jump ? jump_link : (is_load ? load_data : alu_result)); // Writeback mux.
    assign write_en=execute_en && !illegal && !jump_target_misaligned && !reset &&
                    !is_store && !is_branch && (rd!=0) && (is_upper || is_jump || is_load || arithmetic_write);

    regfile rf (.clk(clk),.reset(reset),.we(write_en),.waddr(rd),.wdata(result),
                .raddr1(rs1),.raddr2(rs2),.rdata1(alu_a),.rdata2(rdata2));
    alu calc (.a(alu_a),.b(alu_b),.op(selected_op),.result(alu_result));
endmodule
