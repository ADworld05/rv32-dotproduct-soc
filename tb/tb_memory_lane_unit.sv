`timescale 1ns/1ps

module tb_memory_lane_unit;
    logic [31:0] addr,store_data,read_word,word_addr,write_word,load_value;
    logic [2:0] funct3;
    logic is_store,illegal,misaligned;
    logic [3:0] byte_en;
    int checks=0;
    int boundaries [0:5]='{0,1,32767,32768,65280,65535};
    memory_lane_unit dut (.*);

    task automatic load_case(input int operation,input logic [31:0] address,word,value,
                             input bit bad_encoding,bad_alignment);
        logic [31:0] expected_word_addr;
        addr=address; funct3=operation; is_store=0; read_word=word; store_data=32'hdeadbeef;
        expected_word_addr=address-(address%4);
        #1;
        if ({word_addr,write_word,byte_en,load_value,illegal,misaligned} !==
            {expected_word_addr,32'd0,4'd0,value,bad_encoding,bad_alignment})
            $fatal(1,"Load formatting mismatch funct3=%0d addr=%h",operation,address);
        checks++;
    endtask
    task automatic store_case(input int operation,input logic [31:0] address,data,wanted_word,
                              input logic [3:0] wanted_mask,input bit bad_encoding,bad_alignment);
        logic [31:0] expected_word_addr;
        addr=address; funct3=operation; is_store=1; store_data=data; read_word=32'habcd9876;
        expected_word_addr=address-(address%4);
        #1;
        if ({word_addr,write_word,byte_en,load_value,illegal,misaligned} !==
            {expected_word_addr,wanted_word,wanted_mask,32'd0,bad_encoding,bad_alignment})
            $fatal(1,"Store formatting mismatch funct3=%0d addr=%h",operation,address);
        checks++;
    endtask
    task automatic halfword_cases(input int raw);
        int signed_value;
        logic [31:0] word,expected_store;
        logic [3:0] mask;
        signed_value=(raw<32768) ? raw : raw-65536;
        for(int position=0;position<2;position++) begin
            word=32'h76543210;
            word[(position*16)+:16]=raw;
            load_case(1,16+position*2,word,signed_value,0,0);
            load_case(5,16+position*2,word,raw,0,0);
            expected_store=raw*(position==0 ? 1 : 65536);
            mask=position==0 ? 4'b0011 : 4'b1100;
            store_case(1,16+position*2,32'hface0000 | raw,expected_store,mask,0,0);
        end
    endtask

    initial begin
        // Every 8-bit value at all four byte positions, signed/unsigned loads and SB.
        for(int raw=0;raw<256;raw++) begin
            int signed_value;
            signed_value=(raw<128) ? raw : raw-256;
            for(int lane=0;lane<4;lane++) begin
                logic [31:0] word,wanted_store;
                logic [3:0] mask;
                word=32'h76543210; word[(lane*8)+:8]=raw;
                load_case(0,16+lane,word,signed_value,0,0);
                load_case(4,16+lane,word,raw,0,0);
                wanted_store=raw*(256**lane); mask=2**lane;
                store_case(0,16+lane,32'habcd0000 | raw,wanted_store,mask,0,0);
            end
        end
        for(int b=0;b<6;b++) halfword_cases(boundaries[b]);
        for(int n=0;n<1024;n++) halfword_cases((n*73)&65535);
        for(int n=0;n<16;n++) begin
            logic [31:0] value;
            value=32'h80000000+n*32'h01010101;
            load_case(2,16,value,value,0,0);
            store_case(2,16,value,value,4'b1111,0,0);
        end
        // Reserved funct3 values must produce no byte-write enables or load data.
        for(int f3=0;f3<8;f3++)
            for(int lane=0;lane<4;lane++) begin
                if(f3==3 || f3==6 || f3==7) load_case(f3,16+lane,32'hffffffff,0,1,0);
                if(f3>=3) store_case(f3,16+lane,32'hffffffff,0,0,1,0);
            end
        for(int lane=1;lane<4;lane++) begin
            load_case(2,16+lane,32'hffffffff,0,0,1);
            store_case(2,16+lane,32'hffffffff,0,0,0,1);
            if(lane!=2) begin
                load_case(1,16+lane,32'hffffffff,0,0,1);
                load_case(5,16+lane,32'hffffffff,0,0,1);
                store_case(1,16+lane,32'hffffffff,0,0,0,1);
            end
        end
        $display("PASS: %0d memory-lane checks; byte/halfword extension, masks and alignment",checks);
        $finish;
    end
endmodule
