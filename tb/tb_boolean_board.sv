`timescale 1ns/1ps
module tb_boolean_board;
    logic mclk=0;
    always #5 mclk=~mclk;
    logic [0:0] sw=1;
    wire [15:0] led;
    integer checks=0;
    real last_edge=0;
    boolean_board_top dut(.*);
    always @(posedge dut.core_clk) begin
        if(dut.locked && !dut.core_reset) begin
            if(last_edge!=0 && ($realtime-last_edge<19.99 || $realtime-last_edge>20.01))
                $fatal(1,"Core clock is not 50 MHz");
            last_edge=$realtime;checks++;
        end else last_edge=0;
    end
    initial begin
        repeat(3) begin
            sw=1;last_edge=0;#100;
            if(led[8] || led[9] || led[7:0]!==0 || !led[12])$fatal(1,"Board reset indication failed");checks+=4;
            sw=0;
            wait(led[8] || led[9]);#1;
            if(led!==16'h0904)$fatal(1,"Expected success LED8, lock LED11 and result LED2; got %h",led);checks++;
            #100;
            if(led!==16'h0904)$fatal(1,"Board result did not hold");checks++;
        end
        $display("PASS: %0d Boolean-board checks; real MMCM 100-to-50 MHz, result/status LEDs and reset/restart",checks);$finish;
    end
    initial begin #200000;$fatal(1,"Board simulation timeout");end
endmodule
