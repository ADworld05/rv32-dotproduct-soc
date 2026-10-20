`timescale 1ns/1ps

// Multicycle CPU + RAM/accelerator router: memory-mapped dot-product SoC.
// Instruction ROM stays asynchronous; only data memory uses request/response.
module soc_top #(
    parameter integer PROGRAM_WORDS=4,
    parameter string PROGRAM_FILE="",
    parameter integer MEMORY_LATENCY=2
) (
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] pc_addr,
    output logic [31:0] instr,
    output logic [31:0] instr_pc,
    output logic [2:0]  state,
    output logic        fault,
    output logic        write_en,
    output logic [4:0]  rd,
    output logic [31:0] result,
    output logic [31:0] alu_a,
    output logic [31:0] alu_b,
    output logic        trace_valid,
    output logic [63:0] trace_order,
    output logic [31:0] trace_pc,
    output logic [31:0] trace_instr,
    output logic        trace_rd_write,
    output logic [4:0]  trace_rd,
    output logic [31:0] trace_rd_data,
    output logic        accel_busy,
    output logic        accel_done
);
    logic [31:0] pc_plus4, fetched_instr;
    logic fetched_valid, instr_valid, illegal;
    logic pc_en, ir_en, execute_en;
    logic control_illegal,is_load,is_memory,mem_write;
    logic mem_req_valid,mem_req_ready,mem_rsp_valid,mem_rsp_ready,mem_rsp_fault;
    logic [2:0] mem_funct3;
    logic [31:0] mem_addr,mem_wdata,mem_rsp_rdata,load_data;
    // Response and writeback occur on different edges.
    always_ff @(posedge clk) begin
        if (reset) load_data<=0;
        else if (mem_rsp_valid && mem_rsp_ready && !mem_rsp_fault)
            load_data<=mem_rsp_rdata;
    end
    logic is_branch, branch_taken, target_misaligned, redirect_pc, fetch_pc_en;
    logic [31:0] branch_target, selected_next_pc;
    logic is_jump, jump_target_misaligned;
    logic [31:0] jump_target, redirect_target;
    assign redirect_target=is_jump ? jump_target : branch_target;
    // FETCH advances sequentially; a taken branch or jump redirects the PC at the EXECUTE edge.
    assign redirect_pc=execute_en && ((is_branch && branch_taken) || is_jump) &&
                       !target_misaligned && !jump_target_misaligned && !reset;
    assign fetch_pc_en=pc_en || redirect_pc;
    assign selected_next_pc=redirect_pc ? redirect_target : pc_plus4;
    assign control_illegal=illegal || ((state==3'd2) && (target_misaligned || jump_target_misaligned));

    instruction_fetch #(.WORD_COUNT(PROGRAM_WORDS), .PROGRAM_FILE(PROGRAM_FILE)) fetch_path (
        .clk(clk), .reset(reset), .pc_en(fetch_pc_en), .next_pc(selected_next_pc),
        .pc_addr(pc_addr), .pc_plus4(pc_plus4),
        .instr(fetched_instr), .instr_valid(fetched_valid)
    );
    instruction_reg ir (
        .clk(clk), .reset(reset), .ir_en(ir_en),
        .fetched_instr(fetched_instr), .fetched_pc(pc_addr), .fetched_valid(fetched_valid),
        .instr(instr), .instr_pc(instr_pc), .instr_valid(instr_valid)
    );
    execution_datapath exec_path (
        .clk(clk), .reset(reset), .instr(instr), .execute_en(execute_en),
        .alu_a(alu_a), .alu_b(alu_b), .result(result), .rd(rd),
        .write_en(write_en), .illegal(illegal),
        .load_data(load_data), .is_load(is_load), .is_memory(is_memory),
        .mem_write(mem_write), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_funct3(mem_funct3),
        .instr_pc(instr_pc), .is_branch(is_branch), .branch_taken(branch_taken),
        .branch_target(branch_target), .target_misaligned(target_misaligned),
        .is_jump(is_jump), .jump_target(jump_target), .jump_target_misaligned(jump_target_misaligned)
    );
    soc_memory_port #(.LATENCY(MEMORY_LATENCY)) data_port (
        .clk(clk), .reset(reset), .req_valid(mem_req_valid), .req_ready(mem_req_ready),
        .req_write(mem_write), .req_funct3(mem_funct3), .req_addr(mem_addr), .req_wdata(mem_wdata),
        .rsp_valid(mem_rsp_valid), .rsp_ready(mem_rsp_ready),
        .rsp_rdata(mem_rsp_rdata), .rsp_fault(mem_rsp_fault),
        .accel_busy(accel_busy), .accel_done(accel_done)
    );
    memory_controller control (
        .clk(clk), .reset(reset), .fetched_valid(fetched_valid),
        .instr_valid(instr_valid), .illegal(control_illegal),
        .is_memory(is_memory), .is_load(is_load), .mem_req_ready(mem_req_ready),
        .mem_rsp_valid(mem_rsp_valid), .mem_rsp_fault(mem_rsp_fault),
        .mem_req_valid(mem_req_valid), .mem_rsp_ready(mem_rsp_ready),
        .pc_en(pc_en), .ir_en(ir_en), .execute_en(execute_en),
        .fault(fault), .state(state)
    );
    logic instruction_complete;
    // Loads complete in MEM_WB, other non-stores when execute_en is asserted.
    // A successful store completes only when its response is consumed.
    assign instruction_complete=!reset && (execute_en ||
        ((state==3'd5) && mem_rsp_valid && mem_rsp_ready && !mem_rsp_fault && mem_write));
    instruction_trace trace_report (
        .clk(clk),.reset(reset),.complete(instruction_complete),
        .pc(instr_pc),.instr(instr),.rd_write(write_en),.rd(rd),.rd_data(result),
        .trace_valid(trace_valid),.trace_order(trace_order),.trace_pc(trace_pc),
        .trace_instr(trace_instr),.trace_rd_write(trace_rd_write),
        .trace_rd(trace_rd),.trace_rd_data(trace_rd_data)
    );
    // write_en/rd/result are pre-edge signals. trace_* reports the completed edge.
endmodule
