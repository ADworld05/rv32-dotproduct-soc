`timescale 1ns/1ps

module tb_instruction_fetch;
    logic clk=0;
    always #5 clk=~clk;
    logic reset=1, pc_en=0;
    logic [31:0] next_pc=0, pc_addr, pc_plus4, instr;
    logic instr_valid;
    logic [31:0] probe_addr, probe_instr;
    logic probe_valid;
    logic [31:0] model_pc=0;
    int checks=0;
    instruction_fetch dut (.*);
    instruction_rom rom_probe (.addr(probe_addr), .instr(probe_instr),
                               .instr_valid(probe_valid));

    // Independently recorded instruction words for our four-entry test program.
    function automatic logic [31:0] expected_word(input logic [31:0] address);
        if (address==0) return 32'h00700093;
        if (address==4) return 32'h00a00113;
        if (address==8) return 32'h002081b3;
        if (address==12) return 32'h00119213;
        return 0;
    endfunction
    function automatic bit expected_valid(input logic [31:0] address);
        return (address<16) && ((address%4)==0);
    endfunction

    task automatic check_fetch;
        logic [31:0] sequential;
        sequential=model_pc+32'd4;
        if ({pc_addr,pc_plus4,instr_valid,instr} !==
            {model_pc,sequential,expected_valid(model_pc),expected_word(model_pc)})
            $fatal(1,"Fetch mismatch at expected address %h",model_pc);
        checks++;
    endtask

    task automatic update_pc(input bit rst, enabled, input logic [31:0] target);
        @(negedge clk);
        reset=rst; pc_en=enabled; next_pc=target;
        #1;
        check_fetch(); // Fetch must still reflect the old PC before the edge.
        @(posedge clk);
        model_pc=rst ? 32'd0 : (enabled ? target : model_pc);
        #1;
        check_fetch();
    endtask

    initial begin
        // Every address in/around the program, including unaligned byte addresses.
        for (int address=0; address<16; address++) begin
            probe_addr=address;
            #1;
            if ({probe_valid,probe_instr} !==
                {expected_valid(probe_addr),expected_word(probe_addr)})
                $fatal(1,"ROM mismatch at address %h",probe_addr);
            checks++;
        end
        // Ensure high addresses cannot alias valid ROM words via truncated indexing.
        for (int n=0; n<64; n++) begin
            probe_addr=32'h10000000+n;
            #1;
            if ({probe_valid,probe_instr} !== {1'b0,32'd0})
                $fatal(1,"Out-of-range ROM address accepted");
            checks++;
        end
        // Reset has been held throughout the direct ROM tests.
        check_fetch();
        update_pc(0,1,4);
        update_pc(0,1,8);
        update_pc(0,0,12); // Stall holds both address and instruction.
        update_pc(0,1,12);
        update_pc(0,1,16); // Past the end of the four-word program.
        update_pc(0,1,2);  // Unaligned address.
        update_pc(0,1,32'h10000000);
        update_pc(1,1,12); // Reset returns to the first word despite enabled target.
        $display("PASS: %0d instruction-fetch checks",checks);
        $finish;
    end
endmodule
