`timescale 1ns/1ps

module tb_branch_unit;
    logic [31:0] instr,instr_pc,rs1_value,rs2_value,offset,target,probe_imm;
    logic [4:0] rs1,rs2;
    logic branch_taken,target_misaligned,illegal;
    logic [31:0] values_a [0:9],values_b [0:9];
    int checks=0;
    branch_unit dut (.instr(instr),.instr_pc(instr_pc),.rs1_value(rs1_value),.rs2_value(rs2_value),
                     .rs1(rs1),.rs2(rs2),.offset(offset),.target(target),
                     .branch_taken(branch_taken),.target_misaligned(target_misaligned),.illegal(illegal));
    imm_gen_b probe (.instr(instr),.imm(probe_imm));

    // Arithmetic encoder, independent of the DUT's extraction concatenation.
    function automatic logic [31:0] encode(input int displacement,f3);
        int raw;
        raw=displacement & 8191;
        return ((raw/4096)<<31) | (((raw/32)%64)<<25) | (2<<20) | (1<<15) |
               (f3<<12) | (((raw/2)%16)<<8) | (((raw/2048)%2)<<7) | 32'h63;
    endfunction
    function automatic bit expected_taken(input int f3,input logic [31:0] a,b);
        longint signed a_signed,b_signed;
        a_signed={1'b0,a}; b_signed={1'b0,b};
        if (a_signed>=64'sd2147483648) a_signed=a_signed-64'sd4294967296;
        if (b_signed>=64'sd2147483648) b_signed=b_signed-64'sd4294967296;
        case (f3)
            0: return a==b; 1: return a!=b;
            4: return a_signed<b_signed; 5: return a_signed>=b_signed;
            6: return {1'b0,a}<{1'b0,b}; 7: return {1'b0,a}>={1'b0,b};
            default: return 0;
        endcase
    endfunction
    task automatic check_branch(input int displacement,f3,
                                input logic [31:0] pc_value,a,b);
        logic [31:0] expected_offset,expected_target;
        bit taken,misaligned;
        instr=encode(displacement,f3); instr_pc=pc_value; rs1_value=a; rs2_value=b;
        expected_offset=displacement; expected_target=pc_value+displacement;
        taken=expected_taken(f3,a,b);
        misaligned=taken && ((expected_target%4)!=0);
        #1;
        if ({rs1,rs2,offset,target,branch_taken,target_misaligned,illegal} !==
            {5'd1,5'd2,expected_offset,expected_target,taken,misaligned,1'b0})
            $fatal(1,"Branch mismatch displacement=%0d funct3=%0d",displacement,f3);
        checks++;
    endtask
    task automatic check_invalid(input logic [31:0] word);
        instr=word;
        #1;
        if ({rs1,rs2,offset,target,branch_taken,target_misaligned,illegal} !==
            {5'd0,5'd0,32'd0,32'd0,1'b0,1'b0,1'b1})
            $fatal(1,"Unsupported branch encoding accepted");
        checks++;
    endtask
    initial begin
        instr_pc=0; rs1_value=0; rs2_value=0;
        // Every representable signed byte offset, with two PCs including address wraparound.
        for (int raw=0; raw<4096; raw++) begin
            int displacement;
            logic [31:0] expected_imm;
            displacement=(raw<2048) ? raw*2 : raw*2-8192;
            expected_imm=displacement;
            instr=encode(displacement,0);
            #1;
            if (probe_imm!==expected_imm) $fatal(1,"B immediate mismatch");
            checks++;
            check_branch(displacement,0,256,7,7);
            check_branch(displacement,0,32'hfffffffc,7,7);
        end
        values_a[0]=0; values_b[0]=0;
        values_a[1]=1; values_b[1]=2;
        values_a[2]=2; values_b[2]=1;
        values_a[3]=32'hffffffff; values_b[3]=0;
        values_a[4]=32'h80000000; values_b[4]=32'h7fffffff;
        values_a[5]=32'h7fffffff; values_b[5]=32'h80000000;
        values_a[6]=32'hffffffff; values_b[6]=32'hffffffff;
        values_a[7]=32'h80000000; values_b[7]=32'h80000000;
        values_a[8]=0; values_b[8]=32'hffffffff;
        values_a[9]=32'hffffffff; values_b[9]=1;
        for (int f3=0; f3<8; f3++)
            if (f3!=2 && f3!=3)
                for (int pair=0; pair<10; pair++) begin
                    check_branch(8,f3,100,values_a[pair],values_b[pair]);
                    check_branch(-4,f3,100,values_a[pair],values_b[pair]);
                    check_branch(2,f3,100,values_a[pair],values_b[pair]);
                end
        check_invalid(encode(8,2)); check_invalid(encode(8,3));
        for (int opcode=0; opcode<128; opcode++)
            if (opcode!=99) check_invalid((encode(8,0)&32'hffffff80)|opcode);
        $display("PASS: %0d branch checks; offsets, comparisons, targets and alignment",checks);
        $finish;
    end
endmodule
