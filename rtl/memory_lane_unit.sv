`timescale 1ns/1ps

// Little-endian byte/halfword/word formatting, independent of RAM capacity.
// funct3 is the load/store instruction's bits [14:12]. is_store=0 selects a load.
// Range checks and request enables belong to the memory/CPU integration, not this unit.
module memory_lane_unit (
    input  logic [31:0] addr,
    input  logic [31:0] store_data,
    input  logic [31:0] read_word,
    input  logic [2:0]  funct3,
    input  logic        is_store,
    output logic [31:0] word_addr,
    output logic [31:0] write_word,
    output logic [3:0]  byte_en,
    output logic [31:0] load_value,
    output logic        illegal,
    output logic        misaligned
);
    logic [1:0] size; // 0=byte, 1=halfword, 2=word.
    logic unsigned_load;
    logic [31:0] shifted_word;
    assign word_addr={addr[31:2],2'b00};
    always_comb begin
        write_word=0; byte_en=0; load_value=0;
        illegal=1; misaligned=0; size=0; unsigned_load=0;
        shifted_word=read_word >> (8*addr[1:0]);
        if (is_store) begin
            case(funct3)
                3'b000: begin illegal=0; size=0; end // SB
                3'b001: begin illegal=0; size=1; end // SH
                3'b010: begin illegal=0; size=2; end // SW
                default: illegal=1;
            endcase
        end else begin
            case(funct3)
                3'b000: begin illegal=0; size=0; end // LB
                3'b001: begin illegal=0; size=1; end // LH
                3'b010: begin illegal=0; size=2; end // LW
                3'b100: begin illegal=0; size=0; unsigned_load=1; end // LBU
                3'b101: begin illegal=0; size=1; unsigned_load=1; end // LHU
                default: illegal=1;
            endcase
        end
        if (!illegal) begin
            if (size==1) misaligned=addr[0];
            else if (size==2) misaligned=(addr[1:0]!=0);
            if (!misaligned) begin
                if (is_store) begin
                    case(size)
                        0: begin
                            byte_en=4'b0001 << addr[1:0];
                            write_word={24'd0,store_data[7:0]} << (8*addr[1:0]);
                        end
                        1: begin
                            byte_en=4'b0011 << addr[1:0];
                            write_word={16'd0,store_data[15:0]} << (8*addr[1:0]);
                        end
                        2: begin byte_en=4'b1111; write_word=store_data; end
                        default: begin byte_en=0; write_word=0; end
                    endcase
                end else begin
                    case(size)
                        0: load_value=unsigned_load ? {24'd0,shifted_word[7:0]} :
                                                      {{24{shifted_word[7]}},shifted_word[7:0]};
                        1: load_value=unsigned_load ? {16'd0,shifted_word[15:0]} :
                                                      {{16{shifted_word[15]}},shifted_word[15:0]};
                        2: load_value=read_word;
                        default: load_value=0;
                    endcase
                end
            end
        end
    end
endmodule
