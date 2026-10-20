`timescale 1ns/1ps

module tb_load_store_decode;
    logic [31:0] instr, offset, base, address, s_imm;
    logic [4:0] rs1, rs2, rd;
    logic is_load, is_store, illegal;
    int checks=0;
    load_store_decode dut (.instr(instr),.rs1(rs1),.rs2(rs2),.rd(rd),
                          .offset(offset),.is_load(is_load),.is_store(is_store),.illegal(illegal));
    imm_gen_s s_probe (.instr(instr),.imm(s_imm));
    // The existing ALU can calculate an effective address using ADD.
    alu address_alu (.a(base),.b(offset),.op(4'd0),.result(address));

    function automatic logic [31:0] encode(input bit store, input int raw, f3);
        if (store)
            return ((raw/32)<<25) | (3<<20) | (7<<15) | (f3<<12) |
                   ((raw%32)<<7) | 32'h23;
        return (raw<<20) | (7<<15) | (f3<<12) | (5<<7) | 32'h03;
    endfunction

    task automatic check_invalid(input logic [31:0] word);
        instr=word;
        #1;
        if ({rs1,rs2,rd,offset,is_load,is_store,illegal} !==
            {5'd0,5'd0,5'd0,32'd0,1'b0,1'b0,1'b1})
            $fatal(1,"Unsupported memory encoding accepted: %h",word);
        checks++;
    endtask

    initial begin
        base=0;
        for (int raw=0; raw<4096; raw++) begin
            int signed_value;
            logic [31:0] expected_offset;
            signed_value=(raw<2048) ? raw : raw-4096;
            expected_offset=signed_value;
            instr=encode(1,raw,2);
            #1;
            if (s_imm !== expected_offset) $fatal(1,"S offset mismatch for raw %0d",raw);
            checks++;
            for (int store=0; store<2; store++) begin
                for (int f3=0; f3<8; f3++) begin
                    if (store!=0 ? (f3<=2) : (f3<=2 || f3==4 || f3==5)) begin
                for (int pattern=0; pattern<3; pattern++) begin
                    logic [31:0] expected_address;
                    instr=encode(store!=0,raw,f3);
                    case (pattern)
                        0: base=0;
                        1: base=100;
                        2: base=32'hfffffffc;
                    endcase
                    expected_address=base+signed_value;
                    #1;
                    if ({rs1,rs2,rd,offset,is_load,is_store,illegal,address} !==
                        {5'd7,(store!=0 ? 5'd3 : 5'd0),(store!=0 ? 5'd0 : 5'd5),
                         expected_offset,(store==0),(store!=0),1'b0,expected_address})
                        $fatal(1,"Load/store decode/address mismatch raw=%0d store=%0d",raw,store);
                    checks++;
                end
                end
                end
            end
        end
        for (int f3=0; f3<8; f3++)
            begin
                if (f3==3 || f3==6 || f3==7) check_invalid(encode(0,4095,f3));
                if (f3>=3) check_invalid(encode(1,4095,f3));
            end
        for (int opcode=0; opcode<128; opcode++)
            if (opcode!=3 && opcode!=35)
                check_invalid(32'hfff3a280 | opcode);
        $display("PASS: %0d load/store decode and address checks",checks);
        $finish;
    end
endmodule
