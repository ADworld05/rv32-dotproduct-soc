`timescale 1ns/1ps

module tb_pc;
    logic clk=0;
    always #5 clk=~clk;
    logic reset=0, pc_en=0;
    logic [31:0] next_pc=0, pc_addr, pc_plus4;
    logic [31:0] model, expected, target;
    logic [31:0] sequence_bits=32'h12abcdef;
    int checks=0;
    pc dut (.*);

    task automatic check_state(input logic [31:0] wanted);
        logic [31:0] sequential;
        sequential=wanted+32'd4;
        if ({pc_addr,pc_plus4} !== {wanted,sequential})
            $fatal(1,"PC mismatch: actual=%h expected=%h plus4=%h",
                   pc_addr,wanted,pc_plus4);
        checks++;
    endtask

    task automatic cycle(input bit rst, enabled,
                         input logic [31:0] address);
        @(negedge clk);
        reset=rst; pc_en=enabled; next_pc=address;
        // Changing the input must not change a stored PC before the rising edge.
        #1;
        check_state(model);
        expected=rst ? 32'd0 : (enabled ? address : model);
        @(posedge clk);
        #1; // Let nonblocking register updates settle before sampling.
        model=expected;
        check_state(model);
    endtask

    initial begin
        // Establish a known value with the synchronous reset at the first edge.
        reset=1; pc_en=1; next_pc=32'h100;
        @(posedge clk);
        #1;
        model=0;
        check_state(model);
        cycle(0,1,4);
        cycle(0,1,8);
        cycle(0,0,100); // Hold even though next_pc changes.
        cycle(0,1,32'h100); // Explicit target; branch calculation comes later.
        cycle(1,1,32'h200); // Reset wins over an enabled update.
        cycle(0,1,32'hfffffffc);
        cycle(0,1,pc_plus4); // 32-bit sequential address wraps to zero.

        // Repeat sequences of advance, stall, explicit target and reset.
        // A fixed xorshift sequence makes the targets deterministic.
        for (int n=0; n<1000; n++) begin
            sequence_bits=sequence_bits^(sequence_bits<<13);
            sequence_bits=sequence_bits^(sequence_bits>>17);
            sequence_bits=sequence_bits^(sequence_bits<<5);
            target=sequence_bits & 32'hfffffffc;
            case (n%5)
                0: cycle(0,1,model+32'd4);
                1: cycle(0,0,target);
                2: cycle(0,1,target);
                3: cycle(1,1,target);
                4: cycle(0,1,model+32'd4);
            endcase
        end
        $display("PASS: %0d PC checks",checks);
        $finish;
    end
endmodule
