`timescale 1ns/1ps

module tb_memory_controller;
    logic clk=0;
    always #5 clk=~clk;
    logic reset=1,fetched_valid=1,instr_valid=1,illegal=0,is_memory=1,is_load=1;
    logic mem_req_ready=0,mem_rsp_valid=0,mem_rsp_fault=0;
    logic pc_en,ir_en,execute_en,mem_req_valid,mem_rsp_ready,fault;
    logic [2:0] state;
    int model_state=0,checks=0;
    bit seen [0:6][0:255];
    memory_controller dut (.*);

    task automatic check_outputs;
        logic [2:0] wanted_state;
        bit fetch_permission,write_permission,request_permission,response_permission,wanted_fault,ok;
        wanted_state=model_state;
        ok=instr_valid && !illegal;
        fetch_permission=!reset && model_state==0 && fetched_valid;
        write_permission=!reset && ok && ((model_state==2 && !is_memory) ||
                                         (model_state==6 && is_memory && is_load));
        request_permission=!reset && ok && is_memory && model_state==4;
        response_permission=!reset && ok && is_memory && model_state==5;
        wanted_fault=!reset && model_state==3;
        if ({state,pc_en,ir_en,execute_en,mem_req_valid,mem_rsp_ready,fault} !==
            {wanted_state,fetch_permission,fetch_permission,write_permission,
             request_permission,response_permission,wanted_fault})
            $fatal(1,"Memory-controller output mismatch in state %0d",model_state);
        checks++;
    endtask
    task automatic cycle(input bit rst,input logic [7:0] status);
        int wanted_next;
        bit ok;
        @(negedge clk);
        reset=rst;
        {fetched_valid,instr_valid,illegal,is_memory,is_load,mem_req_ready,mem_rsp_valid,mem_rsp_fault}=status;
        #1;
        check_outputs();
        if (!rst) seen[model_state][status]=1;
        ok=instr_valid && !illegal;
        // Independent numeric transition reference, derived from the state diagram.
        if (rst) wanted_next=0;
        else if (model_state==0) wanted_next=fetched_valid ? 1 : 3;
        else if (model_state==1) wanted_next=ok ? 2 : 3;
        else if (model_state==2) wanted_next=!ok ? 3 : (is_memory ? 4 : 0);
        else if (model_state==3) wanted_next=3;
        else if (model_state==4)
            wanted_next=(!ok || !is_memory) ? 3 : (mem_req_ready ? 5 : 4);
        else if (model_state==5) begin
            if (!ok || !is_memory) wanted_next=3;
            else if (!mem_rsp_valid) wanted_next=5;
            else if (mem_rsp_fault) wanted_next=3;
            else wanted_next=is_load ? 6 : 0;
        end else wanted_next=(ok && is_memory && is_load) ? 0 : 3;
        @(posedge clk);
        model_state=wanted_next;
        #1;
        check_outputs();
    endtask
    task automatic reach(input int target);
        cycle(1,8'hd8); // Valid load, request not yet accepted.
        if (target==3) cycle(0,8'h58); // Invalid fetch -> FAULT.
        else begin
            if (target>=1) cycle(0,8'hd8); // FETCH -> DECODE.
            if (target>=2) cycle(0,8'hd8); // DECODE -> EXECUTE.
            if (target>=4) cycle(0,8'hd8); // EXECUTE -> MEM_REQ.
            if (target>=5) cycle(0,8'hdc); // Request ready -> MEM_WAIT.
            if (target>=6) cycle(0,8'hde); // Successful load response -> MEM_WB.
        end
        if (model_state!=target) $fatal(1,"Test setup did not reach target state");
    endtask
    initial begin
        for(int s=0;s<7;s++) for(int c=0;c<256;c++) seen[s][c]=0;
        @(posedge clk); #1;
        check_outputs();
        // All state/status combinations, reached without forcing internal state.
        for(int target=0;target<7;target++)
            for(int status=0;status<256;status++) begin
                reach(target);
                cycle(0,status);
            end
        // Reset priority at each state, including stalled requests and pending responses.
        for(int target=0;target<7;target++) begin
            reach(target);
            cycle(1,8'hff);
        end
        for(int s=0;s<7;s++) for(int c=0;c<256;c++)
            if (!seen[s][c]) $fatal(1,"Missing controller state/status coverage %0d/%0d",s,c);
        $display("PASS: %0d memory-controller checks; all 1792 state/status combinations and reset",checks);
        $finish;
    end
endmodule
