`timescale 1ns/1ps

module tb_memory_access;
    logic clk=0;
    always #5 clk=~clk;
    logic reset=1,mem_en=0,write_en=0;
    logic [2:0] funct3=0;
    logic [31:0] addr=0,wdata=0,rdata;
    logic access_fault;
    logic [7:0] model_bytes [0:63];
    logic [31:0] pattern=32'h7abcdef1;
    int checks=0;
    memory_access dut (.*);

    logic raw_reset=1,raw_en=0,raw_write=1;
    logic [31:0] raw_addr=4,raw_data=0,raw_read,mask_model=0;
    logic [3:0] raw_mask=0;
    logic raw_fault;
    data_ram_masked raw_ram (.clk(clk),.reset(raw_reset),.mem_en(raw_en),.write_en(raw_write),
        .addr(raw_addr),.wdata(raw_data),.byte_en(raw_mask),.rdata(raw_read),.access_fault(raw_fault));

    function automatic int byte_count(input bit writing,input logic [2:0] operation);
        if (writing) begin
            case(operation) 0:return 1; 1:return 2; 2:return 4; default:return 0; endcase
        end
        case(operation) 0,4:return 1; 1,5:return 2; 2:return 4; default:return 0; endcase
    endfunction
    function automatic bit address_ok(input logic [31:0] address,input int count);
        if (count==0) return 0;
        return (address<64) && ((address%count)==0);
    endfunction
    task automatic check_memory;
        int count;
        bit wanted_fault;
        logic [31:0] wanted_read,word;
        longint signed number;
        count=byte_count(write_en,funct3);
        wanted_fault=!reset && mem_en && !address_ok(addr,count);
        wanted_read=0; number=0;
        if (!reset && mem_en && !write_en && !wanted_fault) begin
            // Independent byte-addressed reference, not the DUT's shift/mask implementation.
            for(int n=0;n<count;n++) number=number+model_bytes[addr+n]*(256**n);
            if (funct3==0 && number>=128) number=number-256;
            if (funct3==1 && number>=32768) number=number-65536;
            wanted_read=number[31:0];
        end
        if ({access_fault,rdata} !== {wanted_fault,wanted_read})
            $fatal(1,"Memory response mismatch addr=%h f3=%0d write=%0b got=%h expected=%h",
                   addr,funct3,write_en,rdata,wanted_read);
        checks++;
        for(int n=0;n<16;n++) begin
            word={model_bytes[n*4+3],model_bytes[n*4+2],model_bytes[n*4+1],model_bytes[n*4]};
            if (dut.ram.words[n]!==word) $fatal(1,"Byte-preservation mismatch word %0d",n);
            checks++;
        end
    endtask
    task automatic access_cycle(input bit rst,active,writing,input int operation,
                                input logic [31:0] address,data);
        int count;
        @(negedge clk);
        reset=rst; mem_en=active; write_en=writing; funct3=operation; addr=address; wdata=data;
        #1; check_memory(); // No storage changes before the write edge.
        @(posedge clk);
        count=byte_count(writing,funct3);
        if (!rst && active && writing && address_ok(address,count))
            for(int n=0;n<count;n++) model_bytes[address+n]=data>>(8*n);
        #1; check_memory();
    endtask
    task automatic mask_cycle(input logic [3:0] mask,input logic [31:0] data,
                              input bit active,rst,input logic [31:0] address);
        bit valid_address;
        @(negedge clk);
        raw_mask=mask; raw_data=data; raw_en=active; raw_reset=rst; raw_addr=address; raw_write=1;
        valid_address=(address<64) && ((address%4)==0);
        #1;
        if (raw_ram.words[1]!==mask_model || raw_fault!==(!rst && active && !valid_address))
            $fatal(1,"Masked RAM pre-edge mismatch");
        checks++;
        @(posedge clk);
        if (!rst && active && valid_address)
            for(int lane=0;lane<4;lane++)
                if (mask[lane]) mask_model[lane*8+:8]=data[lane*8+:8];
        #1;
        if (raw_ram.words[1]!==mask_model) $fatal(1,"Masked RAM byte update mismatch");
        for(int n=0;n<16;n++)
            if (n!=1 && raw_ram.words[n]!==32'd0) $fatal(1,"Masked RAM changed neighboring word");
        checks++;
    endtask

    initial begin
        for(int n=0;n<64;n++) model_bytes[n]=0;
        for(int n=0;n<64;n++) access_cycle(0,1,0,4,n,0);
        for(int n=0;n<16;n++) access_cycle(0,1,1,2,n*4,32'ha0b0c000+n);
        for(int n=0;n<16;n++) begin
            for(int lane=0;lane<4;lane++) access_cycle(0,1,1,0,n*4+lane,32'hdeadbe00+n+lane);
            access_cycle(0,1,0,2,n*4,0);
        end
        for(int n=0;n<32;n++) access_cycle(0,1,1,1,n*2,32'hface8000+n*137);
        for(int n=0;n<32;n++) begin access_cycle(0,1,0,1,n*2,0); access_cycle(0,1,0,5,n*2,0); end
        for(int n=0;n<64;n++) begin access_cycle(0,1,0,0,n,0); access_cycle(0,1,0,4,n,0); end
        access_cycle(0,1,1,0,63,32'h80);
        access_cycle(0,1,0,0,63,0);
        access_cycle(0,1,0,4,63,0);
        access_cycle(0,1,1,1,62,32'h8001);
        access_cycle(0,1,0,1,62,0);
        access_cycle(0,1,1,1,63,32'hffff); // Misaligned, no write.
        access_cycle(0,1,1,2,61,32'hffffffff);
        access_cycle(0,1,1,0,64,32'hff);
        access_cycle(0,1,0,4,64,0);
        access_cycle(0,1,1,0,32'h80000001,32'hff); // No high-address alias.
        access_cycle(0,0,1,0,1,32'hff); // Disabled store.
        access_cycle(1,1,1,0,1,32'hff); // Reset blocks store, preserves all bytes.
        for(int n=0;n<512;n++) begin
            pattern=pattern^(pattern<<13); pattern=pattern^(pattern>>17); pattern=pattern^(pattern<<5);
            access_cycle((n%31)==0,pattern[9],pattern[10],(pattern>>12)%8,pattern%80,pattern);
        end
        for(int n=0;n<16;n++) access_cycle(0,1,0,2,n*4,0);
        // All 16 masks, including zero and non-contiguous selections.
        for(int mask=0;mask<16;mask++) mask_cycle(mask,32'h12345678+mask*32'h01030507,1,0,4);
        mask_cycle(4'b1111,32'hffffffff,0,0,4);
        mask_cycle(4'b1111,32'hffffffff,1,1,4);
        mask_cycle(4'b1111,32'hffffffff,1,0,2);
        mask_cycle(4'b1111,32'hffffffff,1,0,64);
        @(negedge clk); raw_reset=0; raw_en=1; raw_write=0; raw_addr=4;
        #1;
        if ({raw_fault,raw_read} !== {1'b0,mask_model}) $fatal(1,"Masked RAM final read mismatch");
        checks++;
        $display("PASS: %0d subword-memory checks; byte preservation, masks, loads and faults",checks);
        $finish;
    end
endmodule
