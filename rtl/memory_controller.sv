`timescale 1ns/1ps

// Request/response CPU controller. Kept separate from the earlier three-cycle controller.
// The IR and decoded classification must remain stable until the instruction completes.
// On a successful load response, the future CPU top captures rsp_rdata; MEM_WB writes it.
module memory_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic       fetched_valid,
    input  logic       instr_valid,
    input  logic       illegal,
    input  logic       is_memory,
    input  logic       is_load,
    input  logic       mem_req_ready,
    input  logic       mem_rsp_valid,
    input  logic       mem_rsp_fault,
    output logic       pc_en,
    output logic       ir_en,
    output logic       execute_en,
    output logic       mem_req_valid,
    output logic       mem_rsp_ready,
    output logic       fault,
    output logic [2:0] state
);
    typedef enum logic [2:0] {
        FETCH=0,DECODE=1,EXECUTE=2,FAULT=3,MEM_REQ=4,MEM_WAIT=5,MEM_WB=6
    } state_t;
    state_t current_state,next_state;
    logic instruction_ok;
    assign state=current_state;
    assign instruction_ok=instr_valid && !illegal;
    always_ff @(posedge clk) begin
        if (reset) current_state<=FETCH;
        else current_state<=next_state;
    end
    always_comb begin
        next_state=current_state;
        pc_en=0; ir_en=0; execute_en=0;
        mem_req_valid=0; mem_rsp_ready=0; fault=0;
        if (!reset) begin
            case(current_state)
                FETCH: if (fetched_valid) begin
                    pc_en=1; ir_en=1; next_state=DECODE;
                end else next_state=FAULT;
                DECODE: next_state=instruction_ok ? EXECUTE : FAULT;
                EXECUTE: if (!instruction_ok) next_state=FAULT;
                    else if (is_memory) next_state=MEM_REQ;
                    else begin execute_en=1; next_state=FETCH; end
                MEM_REQ: if (!instruction_ok || !is_memory) next_state=FAULT;
                    else begin
                        mem_req_valid=1; // Remains asserted until acceptance.
                        if (mem_req_ready) next_state=MEM_WAIT;
                    end
                MEM_WAIT: if (!instruction_ok || !is_memory) next_state=FAULT;
                    else begin
                        mem_rsp_ready=1;
                        if (mem_rsp_valid) begin
                            if (mem_rsp_fault) next_state=FAULT;
                            else if (is_load) next_state=MEM_WB;
                            else next_state=FETCH; // Store has already completed.
                        end
                    end
                MEM_WB: if (!instruction_ok || !is_memory || !is_load) next_state=FAULT;
                    else begin execute_en=1; next_state=FETCH; end
                FAULT: begin fault=1; next_state=FAULT; end
                default: next_state=FAULT;
            endcase
        end
    end
    // No PC advance, IR overwrite or register write while requesting/waiting.
endmodule
