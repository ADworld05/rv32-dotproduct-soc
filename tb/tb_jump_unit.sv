`timescale 1ns/1ps

module tb_jump_unit;
    logic [31:0] instr,instr_pc,rs1_value,offset,target,link_data,probe_imm;
    logic [4:0] rs1,rd;
    logic is_jump,target_misaligned,illegal;
    logic [31:0] pattern=32'habc12345;
    int checks=0;
    int boundaries [0:5]='{-1048576,-4,-2,0,2,1048574};
    logic [31:0] bases [0:5]='{32'd0,32'd1,32'd2,32'd3,32'd100,32'hfffffffc};
    jump_unit dut (.instr(instr),.instr_pc(instr_pc),.rs1_value(rs1_value),.rs1(rs1),.rd(rd),
                   .offset(offset),.target(target),.link_data(link_data),.is_jump(is_jump),
                   .target_misaligned(target_misaligned),.illegal(illegal));
    imm_gen_j probe (.instr(instr),.imm(probe_imm));

    // Arithmetic packing independently checks the DUT's concatenated extraction.
    function automatic logic [31:0] jal_word(input int displacement,destination);
        int raw;
        raw=displacement & 2097151;
        return ((raw/1048576)<<31) | (((raw/2)%1024)<<21) |
               (((raw/2048)%2)<<20) | (((raw/4096)%256)<<12) | (destination<<7) | 32'h6f;
    endfunction
    task automatic check_jal(input int displacement,destination,input logic [31:0] pc_value);
        logic [31:0] wanted_offset,wanted_target,wanted_link;
        logic [4:0] wanted_rd;
        bit misaligned;
        instr=jal_word(displacement,destination); instr_pc=pc_value; rs1_value=32'hdeadbeef;
        wanted_offset=displacement; wanted_target=pc_value+displacement;
        wanted_link=pc_value+4; wanted_rd=destination;
        misaligned=(wanted_target%4)!=0;
        #1;
        if ({probe_imm,rs1,rd,offset,target,link_data,is_jump,target_misaligned,illegal} !==
            {wanted_offset,5'd0,wanted_rd,wanted_offset,wanted_target,wanted_link,1'b1,misaligned,1'b0})
            $fatal(1,"JAL mismatch displacement=%0d rd=%0d",displacement,destination);
        checks++;
    endtask
    task automatic check_jalr(input int displacement,destination,input logic [31:0] base);
        logic [31:0] wanted_offset,wanted_target;
        logic [4:0] wanted_rd;
        bit misaligned;
        instr=((displacement & 4095)<<20) | (5<<15) | (destination<<7) | 32'h67;
        instr_pc=100; rs1_value=base;
        wanted_offset=displacement; wanted_target=base+displacement;
        if ((wanted_target%2)!=0) wanted_target=wanted_target-1;
        wanted_rd=destination; misaligned=(wanted_target%4)!=0;
        #1;
        if ({rs1,rd,offset,target,link_data,is_jump,target_misaligned,illegal} !==
            {5'd5,wanted_rd,wanted_offset,wanted_target,32'd104,1'b1,misaligned,1'b0})
            $fatal(1,"JALR mismatch displacement=%0d base=%h",displacement,base);
        checks++;
    endtask
    task automatic check_invalid(input logic [31:0] word);
        instr=word;
        #1;
        if ({rs1,rd,offset,target,link_data,is_jump,target_misaligned,illegal} !==
            {5'd0,5'd0,32'd0,32'd0,32'd0,1'b0,1'b0,1'b1})
            $fatal(1,"Unsupported jump encoding accepted");
        checks++;
    endtask
    initial begin
        instr_pc=0; rs1_value=0;
        // Walking single bits and their complements cover every scattered J field.
        for (int bit_number=0;bit_number<20;bit_number++) begin
            int raw,displacement;
            raw=1<<bit_number;
            displacement=(raw<524288) ? raw*2 : raw*2-2097152;
            check_jal(displacement,1,100);
            raw=1048575-raw;
            displacement=(raw<524288) ? raw*2 : raw*2-2097152;
            check_jal(displacement,1,100);
        end
        for (int b=0;b<6;b++)
            for (int r=0;r<3;r++) begin
                check_jal(boundaries[b],(r==0 ? 0 : (r==1 ? 1 : 31)),100);
                check_jal(boundaries[b],(r==0 ? 0 : (r==1 ? 1 : 31)),32'hfffffffc);
            end
        for (int n=0;n<1024;n++) begin
            int raw,displacement;
            pattern=pattern^(pattern<<13); pattern=pattern^(pattern>>17); pattern=pattern^(pattern<<5);
            raw=pattern & 1048575;
            displacement=(raw<524288) ? raw*2 : raw*2-2097152;
            check_jal(displacement,n%32,pattern & 32'hfffffffc);
        end
        // Every 12-bit JALR offset, odd/even bases, x0 and overlapping rd/rs1 cases.
        for (int raw=0;raw<4096;raw++)
            for (int b=0;b<6;b++)
                check_jalr((raw<2048 ? raw : raw-4096),raw%32,bases[b]);
        for (int f3=1;f3<8;f3++) check_invalid(32'h000280e7 | (f3<<12));
        for (int opcode=0;opcode<128;opcode++)
            if (opcode!=103 && opcode!=111) check_invalid(32'h00028080 | opcode);
        $display("PASS: %0d jump checks; JAL/JALR offsets, targets, link and alignment",checks);
        $finish;
    end
endmodule
