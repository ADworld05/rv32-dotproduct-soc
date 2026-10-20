`timescale 1ns/1ps

module tb_upper_imm_unit;
    logic [31:0] instr,instr_pc,imm,result,probe_imm;
    logic [4:0] rd;
    logic is_upper,illegal;
    logic [31:0] pattern=32'h2765abcd;
    int checks=0;
    int boundaries [0:5]='{0,1,524287,524288,1048575,74565};
    logic [31:0] pcs [0:3]='{32'd0,32'd100,32'hfffffffc,32'h80000000};
    upper_imm_unit dut (.instr(instr),.instr_pc(instr_pc),.rd(rd),.imm(imm),
                        .result(result),.is_upper(is_upper),.illegal(illegal));
    imm_gen_u probe (.instr(instr),.imm(probe_imm));

    task automatic check_upper(input int field_value,destination,input bit auipc,
                               input logic [31:0] pc_value);
        longint unsigned wide_imm,wide_result;
        logic [31:0] wanted_imm,wanted_result;
        logic [4:0] wanted_rd;
        instr=(field_value<<12)|(destination<<7)|(auipc ? 32'h17 : 32'h37);
        instr_pc=pc_value;
        // Independent arithmetic reference uses 64-bit multiplication then truncation.
        wide_imm=field_value;
        wide_imm=wide_imm*4096;
        wide_result=auipc ? wide_imm+pc_value : wide_imm;
        wanted_imm=wide_imm[31:0]; wanted_result=wide_result[31:0]; wanted_rd=destination;
        #1;
        if ({probe_imm,rd,imm,result,is_upper,illegal} !==
            {wanted_imm,wanted_rd,wanted_imm,wanted_result,1'b1,1'b0})
            $fatal(1,"Upper-immediate mismatch field=%h rd=%0d AUIPC=%0b PC=%h",
                   field_value,destination,auipc,pc_value);
        checks++;
    endtask
    task automatic check_invalid(input int opcode);
        instr=32'hfffff080 | opcode;
        #1;
        if ({rd,imm,result,is_upper,illegal} !== {5'd0,32'd0,32'd0,1'b0,1'b1})
            $fatal(1,"Unsupported upper-immediate opcode accepted");
        checks++;
    endtask

    initial begin
        instr_pc=0;
        // All twenty upper-field bits, both single-bit and complement patterns.
        for(int bit_number=0;bit_number<20;bit_number++)
            for(int complement=0;complement<2;complement++)
                for(int operation=0;operation<2;operation++)
                    for(int pc_index=0;pc_index<3;pc_index++)
                        check_upper(complement ? (1048575^(1<<bit_number)) : (1<<bit_number),
                                    5,operation!=0,pcs[pc_index]);
        // Boundary values, wraparound, and the high PC bit.
        for(int b=0;b<6;b++)
            for(int operation=0;operation<2;operation++)
                for(int pc_index=0;pc_index<4;pc_index++)
                    check_upper(boundaries[b],1,operation!=0,pcs[pc_index]);
        // Every destination, including x0. Values remain calculations until integration.
        for(int destination=0;destination<32;destination++)
            for(int operation=0;operation<2;operation++)
                check_upper(74565,destination,operation!=0,100);
        // Fixed xorshift input sequence gives repeatable varied fields.
        for(int n=0;n<1024;n++) begin
            pattern=pattern^(pattern<<13); pattern=pattern^(pattern>>17); pattern=pattern^(pattern<<5);
            for(int operation=0;operation<2;operation++)
                for(int pc_index=0;pc_index<3;pc_index++)
                    check_upper(pattern & 1048575,n%32,operation!=0,pcs[pc_index]);
        end
        for(int opcode=0;opcode<128;opcode++)
            if(opcode!=23 && opcode!=55) check_invalid(opcode);
        $display("PASS: %0d upper-immediate checks; LUI/AUIPC, destinations and wraparound",checks);
        $finish;
    end
endmodule
