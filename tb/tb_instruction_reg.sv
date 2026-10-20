`timescale 1ns/1ps

module tb_instruction_reg;
    logic clk=0;
    always #5 clk=~clk;
    // Standalone register: varied inputs and capture/hold/reset combinations.
    logic reset=1, ir_en=0, fetched_valid=0;
    logic [31:0] fetched_instr=0, fetched_pc=0, instr, instr_pc;
    logic instr_valid;
    logic [31:0] model_instr=0, model_pc=0;
    bit model_valid=0;
    logic [31:0] pattern=32'h76543210;
    int checks=0;
    instruction_reg unit_dut (.*);

    // Integration: capture a ROM instruction while the PC advances at the same edge.
    logic fetch_reset=1, pc_en=0, capture_en=0;
    logic [31:0] pc_addr, pc_plus4, raw_instr, held_instr, held_pc;
    logic raw_valid, held_valid;
    logic [31:0] expected_pc=0, expected_held_instr=0, expected_held_pc=0;
    bit expected_held_valid=0;
    instruction_fetch fetch_dut (
        .clk(clk), .reset(fetch_reset), .pc_en(pc_en), .next_pc(pc_plus4),
        .pc_addr(pc_addr), .pc_plus4(pc_plus4), .instr(raw_instr), .instr_valid(raw_valid)
    );
    instruction_reg capture_dut (
        .clk(clk), .reset(fetch_reset), .ir_en(capture_en),
        .fetched_instr(raw_instr), .fetched_pc(pc_addr), .fetched_valid(raw_valid),
        .instr(held_instr), .instr_pc(held_pc), .instr_valid(held_valid)
    );

    task automatic check_unit;
        if ({instr,instr_pc,instr_valid} !== {model_instr,model_pc,model_valid})
            $fatal(1,"Instruction-register storage mismatch");
        checks++;
    endtask
    task automatic unit_cycle(input bit rst, enabled, valid,
                              input logic [31:0] word, address);
        @(negedge clk);
        reset=rst; ir_en=enabled; fetched_valid=valid;
        fetched_instr=word; fetched_pc=address;
        #1;
        check_unit(); // Input changes must not alter storage before the edge.
        @(posedge clk);
        if (rst) begin model_instr=0; model_pc=0; model_valid=0; end
        else if (enabled) begin
            model_instr=word; model_pc=address; model_valid=valid;
        end
        #1;
        check_unit();
    endtask

    function automatic logic [31:0] rom_word(input logic [31:0] address);
        case (address)
            0: return 32'h00700093;
            4: return 32'h00a00113;
            8: return 32'h002081b3;
            12: return 32'h00119213;
            default: return 0;
        endcase
    endfunction
    function automatic bit rom_valid(input logic [31:0] address);
        return (address<16) && (address%4==0);
    endfunction
    task automatic check_integration;
        if ({pc_addr,raw_instr,raw_valid,held_instr,held_pc,held_valid} !==
            {expected_pc,rom_word(expected_pc),rom_valid(expected_pc),
             expected_held_instr,expected_held_pc,expected_held_valid})
            $fatal(1,"PC/ROM/instruction-register integration mismatch");
        checks++;
    endtask
    task automatic fetch_cycle(input bit rst, advance, capture);
        @(negedge clk);
        fetch_reset=rst; pc_en=advance; capture_en=capture;
        #1;
        check_integration();
        @(posedge clk);
        if (rst) begin
            expected_pc=0; expected_held_instr=0;
            expected_held_pc=0; expected_held_valid=0;
        end else begin
            // Reference captures the old PC's instruction before advancing the PC.
            if (capture) begin
                expected_held_instr=rom_word(expected_pc);
                expected_held_pc=expected_pc;
                expected_held_valid=rom_valid(expected_pc);
            end
            if (advance) expected_pc=expected_pc+32'd4;
        end
        #1;
        check_integration();
    endtask

    initial begin
        @(posedge clk);
        #1;
        check_unit();
        for (int n=0; n<128; n++) begin
            pattern=pattern^(pattern<<13);
            pattern=pattern^(pattern>>17);
            pattern=pattern^(pattern<<5);
            unit_cycle((n%17)==0,(n%3)!=0,(n%4)!=0,
                       pattern,(pattern^32'h12340000)&32'hfffffffc);
        end
        // Stop standalone captures before exercising the integrated path.
        @(negedge clk);
        reset=0; ir_en=0;
        #1;
        check_integration();
        fetch_cycle(0,1,1); // IR gets address 0; PC advances to 4.
        fetch_cycle(0,0,0); // Both hold.
        fetch_cycle(0,1,0); // PC advances but the held instruction stays unchanged.
        fetch_cycle(0,1,1); // Capture address 8 while advancing to 12.
        fetch_cycle(0,1,1); // Capture address 12 while advancing outside the ROM.
        fetch_cycle(0,0,1); // Invalid fetch clears stored validity, replacing old word.
        fetch_cycle(1,1,1); // Reset wins over both enables.
        fetch_cycle(0,0,1); // Capture without a PC update.
        $display("PASS: %0d instruction-register checks",checks);
        $finish;
    end
endmodule
