`timescale 1ns/1ps

module soc_program_case #(
    parameter integer LATENCY=2,
    parameter string FILE="dotproduct_learning.hex",
    parameter logic [31:0] A=32'h0403fe01,B=32'h08f90605,
    parameter integer ANSWER=4
) (output logic done=0,output integer checks=0);
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic fault,accel_busy,accel_done,trace_valid,trace_rd_write;
    logic [63:0] trace_order;
    logic [31:0] trace_pc,trace_instr,trace_rd_data;
    logic [4:0] trace_rd;
    logic [31:0] program_words[0:14],model_regs[0:31];
    integer seen=0,requests=0,responses=0,accesses=0,starts=0;
    logic [2:0] state;
    logic [63:0] cycle_count,retired_count,memory_wait_count,cycles_at_last_retire,waits_at_last_retire;
    soc_top #(.PROGRAM_WORDS(15),.MEMORY_LATENCY(LATENCY),
      .PROGRAM_FILE({"programs/soc/",FILE})) dut
      (.clk(clk),.reset(reset),.state(state),.fault(fault),.accel_busy(accel_busy),.accel_done(accel_done),
       .trace_valid(trace_valid),.trace_order(trace_order),.trace_pc(trace_pc),.trace_instr(trace_instr),
       .trace_rd_write(trace_rd_write),.trace_rd(trace_rd),.trace_rd_data(trace_rd_data));
    performance_counters meter(.clk(clk),.reset(reset),.active(!fault),.retire_valid(trace_valid),
      .memory_wait(state==5),.cycle_count(cycle_count),.retired_count(retired_count),
      .memory_wait_count(memory_wait_count),.cycles_at_last_retire(cycles_at_last_retire),
      .waits_at_last_retire(waits_at_last_retire));
    always @(posedge clk) if(!reset && !done) begin
        if(dut.mem_req_valid && dut.mem_req_ready) requests++;
        if(dut.mem_rsp_valid && dut.mem_rsp_ready) begin
            responses++;
            if(dut.mem_rsp_fault) $fatal(1,"Valid accelerator program received a memory fault");
        end
        if(dut.data_port.backend_en) accesses++;
        if(dut.data_port.accelerator.start) starts++;
        if((state==4 || state==5) && dut.write_en) $fatal(1,"Early CPU register write");
        checks++;
    end
    logic expected_write;
    logic [4:0] expected_rd;
    logic [31:0] expected_value;
    always @(negedge clk) if(!reset && !done) begin
        if(trace_valid) begin
            if(seen>=15 || trace_order!==seen || trace_pc!==seen*4 || trace_instr!==program_words[seen])
                $fatal(1,"SoC program trace order/PC/instruction mismatch %s",FILE);
            checks+=3;
            expected_write=1;expected_rd=0;expected_value=0;
            case(seen)
                0: begin expected_rd=1;expected_value=32'h10000000;end
                1: begin expected_rd=2;expected_value=(A+32'h800)&32'hfffff000;end
                2: begin expected_rd=2;expected_value=A;end
                3: begin expected_rd=3;expected_value=(B+32'h800)&32'hfffff000;end
                4: begin expected_rd=3;expected_value=B;end
                7: begin expected_rd=4;expected_value=1;end
                9,10: begin expected_rd=5;expected_value=2;end
                12: begin expected_rd=6;expected_value=ANSWER;end
                14: begin expected_rd=7;expected_value=ANSWER;end
                default: expected_write=0;
            endcase
            if(trace_rd_write!==expected_write || trace_rd!==expected_rd || trace_rd_data!==expected_value)
                $fatal(1,"SoC register effect mismatch %s step %0d got x%0d=%h",FILE,seen,trace_rd,trace_rd_data);
            checks+=3;
            if(expected_write) model_regs[expected_rd]=expected_value;
            seen++;
        end
        for(int n=1;n<32;n++) begin
            if(dut.exec_path.rf.regs[n]!==model_regs[n]) $fatal(1,"SoC register storage mismatch");
            checks++;
        end
    end
    initial begin
        $readmemh({"programs/soc/",FILE},program_words);
        for(int n=0;n<32;n++) model_regs[n]=0;
        @(negedge clk);reset=0;
        wait(fault);repeat(3) @(negedge clk);#1;
        if(seen!=15 || requests!=7 || responses!=7 || accesses!=7 || starts!=1 ||
           accel_busy || !accel_done || dut.data_port.accelerator.regs.result_reg!==ANSWER ||
           retired_count!==15 || cycles_at_last_retire!==(62+7*LATENCY) ||
           waits_at_last_retire!==(7*(LATENCY+1)))
            $fatal(1,"SoC completion/accounting mismatch %s latency %0d cycles=%0d",FILE,LATENCY,cycles_at_last_retire);
        checks+=11;
        for(int n=0;n<16;n++) begin
            if(dut.data_port.ram_target.ram.words[n]!==((n==0)?ANSWER:0)) $fatal(1,"SoC RAM result/preservation mismatch");
            checks++;
        end
        $display("SOC,%s,latency=%0d,result=%0d,cycles=%0d,instructions=%0d",FILE,LATENCY,ANSWER,cycles_at_last_retire,retired_count);
        done=1;
    end
endmodule

module soc_fault_case #(
    parameter integer LATENCY=2,
    parameter string FILE="bad_reserved.hex",
    parameter logic [31:0] BASE=32'h10000000
) (output logic done=0,output integer checks=0);
    logic clk=0,reset=1;
    always #5 clk=~clk;
    logic fault,trace_valid;
    logic [31:0] trace_pc,trace_instr,trace_rd_data;
    logic [4:0] trace_rd;
    logic trace_rd_write;
    integer seen=0,fault_responses=0;
    soc_top #(.PROGRAM_WORDS(3),.MEMORY_LATENCY(LATENCY),
      .PROGRAM_FILE({"programs/soc/",FILE})) dut
      (.clk(clk),.reset(reset),.fault(fault),.trace_valid(trace_valid),.trace_pc(trace_pc),
       .trace_instr(trace_instr),.trace_rd_write(trace_rd_write),.trace_rd(trace_rd),.trace_rd_data(trace_rd_data));
    always @(posedge clk) if(!reset && !done && dut.mem_rsp_valid && dut.mem_rsp_ready && dut.mem_rsp_fault)
        fault_responses++;
    always @(negedge clk) if(!reset && !done && trace_valid) begin
        if(seen>=2 || trace_pc!==seen*4 || !trace_rd_write ||
           trace_rd!==((seen==0)?1:6) || trace_rd_data!==((seen==0)?BASE:77))
            $fatal(1,"Faulting operation retired or damaged prior instruction %s",FILE);
        seen++;checks+=4;
    end
    initial begin
        @(negedge clk);reset=0;
        wait(fault);repeat(3) @(negedge clk);#1;
        if(seen!=2 || fault_responses!=1 || dut.exec_path.rf.regs[1]!==BASE ||
           dut.exec_path.rf.regs[6]!==77 || dut.write_en || dut.mem_req_valid ||
           dut.accel_busy || dut.accel_done || dut.data_port.accelerator.operand_a!==0)
            $fatal(1,"SoC did not stop cleanly on MMIO fault %s",FILE);
        checks+=9;
        for(int n=0;n<16;n++) begin
            if(dut.data_port.ram_target.ram.words[n]!==0) $fatal(1,"Faulting SoC changed RAM");
            checks++;
        end
        done=1;
    end
endmodule

module soc_reset_case(output logic done=0,output integer checks=0);
    logic clk=0,reset=1,fault;
    always #5 clk=~clk;
    soc_top #(.PROGRAM_WORDS(15),.MEMORY_LATENCY(4),
      .PROGRAM_FILE("programs/soc/dotproduct_learning.hex")) dut
      (.clk(clk),.reset(reset),.fault(fault));
    initial begin
        @(negedge clk);reset=0;
        wait(dut.data_port.accelerator.start);
        @(negedge clk);reset=1;
        @(posedge clk);#1;
        if(dut.accel_busy || dut.accel_done || dut.data_port.rsp_valid || dut.exec_path.rf.regs[1]!==0)
            $fatal(1,"SoC reset failed during accelerator launch");checks+=4;
        @(negedge clk);reset=0;
        wait(fault);repeat(2) @(negedge clk);
        if(dut.exec_path.rf.regs[6]!==4 || dut.exec_path.rf.regs[7]!==4 ||
           dut.data_port.ram_target.ram.words[0]!==4 || !dut.accel_done)
            $fatal(1,"SoC did not restart successfully");checks+=4;
        reset=1;@(posedge clk);#1;
        if(dut.exec_path.rf.regs[6]!==0 || dut.accel_busy || dut.accel_done ||
           dut.data_port.ram_target.ram.words[0]!==4)
            $fatal(1,"SoC reset retention policy mismatch");checks+=4;
        done=1;
    end
endmodule

module tb_soc_top;
wire [30:0] done;
wire [31:0] checks[0:30];
soc_program_case #(.LATENCY(1),.FILE("dotproduct_learning.hex"),.A(32'h0403fe01),.B(32'h08f90605),.ANSWER(4)) c0(done[0],checks[0]);
soc_program_case #(.LATENCY(1),.FILE("dotproduct_negative.hex"),.A(32'h01010101),.B(32'hffffffff),.ANSWER(-4)) c1(done[1],checks[1]);
soc_program_case #(.LATENCY(1),.FILE("dotproduct_maximum.hex"),.A(32'h80808080),.B(32'h80808080),.ANSWER(65536)) c2(done[2],checks[2]);
soc_program_case #(.LATENCY(1),.FILE("dotproduct_minimum.hex"),.A(32'h80808080),.B(32'h7f7f7f7f),.ANSWER(-65024)) c3(done[3],checks[3]);
soc_fault_case #(.LATENCY(1),.FILE("bad_reserved.hex"),.BASE(32'h10000000)) c4(done[4],checks[4]);
soc_fault_case #(.LATENCY(1),.FILE("bad_readonly.hex"),.BASE(32'h10000000)) c5(done[5],checks[5]);
soc_fault_case #(.LATENCY(1),.FILE("bad_width.hex"),.BASE(32'h10000000)) c6(done[6],checks[6]);
soc_fault_case #(.LATENCY(1),.FILE("bad_alignment.hex"),.BASE(32'h10000000)) c7(done[7],checks[7]);
soc_fault_case #(.LATENCY(1),.FILE("bad_unmapped.hex"),.BASE(32'h20000000)) c8(done[8],checks[8]);
soc_fault_case #(.LATENCY(1),.FILE("bad_control.hex"),.BASE(32'h10000000)) c9(done[9],checks[9]);
soc_program_case #(.LATENCY(2),.FILE("dotproduct_learning.hex"),.A(32'h0403fe01),.B(32'h08f90605),.ANSWER(4)) c10(done[10],checks[10]);
soc_program_case #(.LATENCY(2),.FILE("dotproduct_negative.hex"),.A(32'h01010101),.B(32'hffffffff),.ANSWER(-4)) c11(done[11],checks[11]);
soc_program_case #(.LATENCY(2),.FILE("dotproduct_maximum.hex"),.A(32'h80808080),.B(32'h80808080),.ANSWER(65536)) c12(done[12],checks[12]);
soc_program_case #(.LATENCY(2),.FILE("dotproduct_minimum.hex"),.A(32'h80808080),.B(32'h7f7f7f7f),.ANSWER(-65024)) c13(done[13],checks[13]);
soc_fault_case #(.LATENCY(2),.FILE("bad_reserved.hex"),.BASE(32'h10000000)) c14(done[14],checks[14]);
soc_fault_case #(.LATENCY(2),.FILE("bad_readonly.hex"),.BASE(32'h10000000)) c15(done[15],checks[15]);
soc_fault_case #(.LATENCY(2),.FILE("bad_width.hex"),.BASE(32'h10000000)) c16(done[16],checks[16]);
soc_fault_case #(.LATENCY(2),.FILE("bad_alignment.hex"),.BASE(32'h10000000)) c17(done[17],checks[17]);
soc_fault_case #(.LATENCY(2),.FILE("bad_unmapped.hex"),.BASE(32'h20000000)) c18(done[18],checks[18]);
soc_fault_case #(.LATENCY(2),.FILE("bad_control.hex"),.BASE(32'h10000000)) c19(done[19],checks[19]);
soc_program_case #(.LATENCY(4),.FILE("dotproduct_learning.hex"),.A(32'h0403fe01),.B(32'h08f90605),.ANSWER(4)) c20(done[20],checks[20]);
soc_program_case #(.LATENCY(4),.FILE("dotproduct_negative.hex"),.A(32'h01010101),.B(32'hffffffff),.ANSWER(-4)) c21(done[21],checks[21]);
soc_program_case #(.LATENCY(4),.FILE("dotproduct_maximum.hex"),.A(32'h80808080),.B(32'h80808080),.ANSWER(65536)) c22(done[22],checks[22]);
soc_program_case #(.LATENCY(4),.FILE("dotproduct_minimum.hex"),.A(32'h80808080),.B(32'h7f7f7f7f),.ANSWER(-65024)) c23(done[23],checks[23]);
soc_fault_case #(.LATENCY(4),.FILE("bad_reserved.hex"),.BASE(32'h10000000)) c24(done[24],checks[24]);
soc_fault_case #(.LATENCY(4),.FILE("bad_readonly.hex"),.BASE(32'h10000000)) c25(done[25],checks[25]);
soc_fault_case #(.LATENCY(4),.FILE("bad_width.hex"),.BASE(32'h10000000)) c26(done[26],checks[26]);
soc_fault_case #(.LATENCY(4),.FILE("bad_alignment.hex"),.BASE(32'h10000000)) c27(done[27],checks[27]);
soc_fault_case #(.LATENCY(4),.FILE("bad_unmapped.hex"),.BASE(32'h20000000)) c28(done[28],checks[28]);
soc_fault_case #(.LATENCY(4),.FILE("bad_control.hex"),.BASE(32'h10000000)) c29(done[29],checks[29]);
soc_reset_case resets(done[30],checks[30]);
integer total;
initial begin wait(&done);#2;total=0;for(int n=0;n<31;n++)total+=checks[n];
$display("PASS: %0d CPU/SoC checks; 12 accelerator programs, 18 MMIO fault cases, latency 1/2/4 and reset/restart",total);$finish;end
initial begin #20000;$fatal(1,"SoC integration timeout");end
endmodule
