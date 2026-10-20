`timescale 1ns/1ps

module tb_address_decoder;
    logic access_en=0;
    logic [31:0] addr=0;
    logic ram_sel,accel_sel,decode_fault;
    logic [4:0] accel_offset;
    integer checks=0,cases_run=0;
    address_decoder dut(.*);
    task automatic check(input bit enabled,input logic [31:0] address,
                         input bit ram_expected,accel_expected,fault_expected,
                         input logic [4:0] offset_expected);
        access_en=enabled;addr=address;#1;
        if(ram_sel!==ram_expected || accel_sel!==accel_expected ||
           decode_fault!==fault_expected || accel_offset!==offset_expected)
            $fatal(1,"Decode mismatch en=%b addr=%h got ram=%b accel=%b fault=%b offset=%0d",
                access_en,addr,ram_sel,accel_sel,decode_fault,accel_offset);
        checks+=4;cases_run++;
        if((ram_sel && accel_sel) || (decode_fault && (ram_sel || accel_sel)))
            $fatal(1,"Decoder selected more than one outcome");
        checks++;
    endtask
    task automatic miss(input logic [31:0] address);
        check(1,address,0,0,1,0);
        check(0,address,0,0,0,0);
    endtask
    initial begin
        // Every byte in each window, including unaligned byte addresses.
        for(int n=0;n<64;n++) begin
            check(1,n,1,0,0,0);check(0,n,0,0,0,0);
        end
        for(int n=0;n<32;n++) begin
            check(1,32'h10000000+n,0,1,0,n);
            check(0,32'h10000000+n,0,0,0,0);
        end
        miss(32'h00000040);miss(32'h00000041);miss(32'h0fffffff);
        miss(32'h10000020);miss(32'h10000021);miss(32'hffffffff);
        // Prevent aliases caused by checking only low address bits.
        for(int bit_number=6;bit_number<32;bit_number++)
            if(bit_number!=28) miss((32'h1<<bit_number)|32'h3);
        for(int bit_number=5;bit_number<32;bit_number++)
            if(bit_number!=28) miss(32'h10000003|(32'h1<<bit_number));
        // Addresses in independently known unmapped regions across high nibbles.
        for(int n=0;n<512;n++)
            miss(32'h20000000|($urandom & 32'h0fffffff));
        // Consecutive target changes exercise clearing of all combinational outputs.
        repeat(8) begin
            check(1,32'h1000001c,0,1,0,28);
            check(1,32'h0000003c,1,0,0,0);
            check(1,32'hffffffff,0,0,1,0);
            check(0,32'h10000004,0,0,0,0);
        end
        $display("PASS: %0d address-decoder checks; %0d cases, all mapped bytes, boundaries, aliases and inactive requests",
                 checks,cases_run);
        $finish;
    end
endmodule
