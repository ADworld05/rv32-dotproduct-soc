`timescale 1ns/1ps

// One-outstanding-request router: fixed 64-byte RAM + dot-product accelerator.
// LATENCY counts edges after request acceptance until one backend access.
// Request/response behavior matches memory_port; accelerator compute runs freely.
module soc_memory_port #(
    parameter integer LATENCY=2
) (
    input logic clk,reset,
    input logic req_valid,
    output logic req_ready,
    input logic req_write,
    input logic [2:0] req_funct3,
    input logic [31:0] req_addr,req_wdata,
    output logic rsp_valid,
    input logic rsp_ready,
    output logic [31:0] rsp_rdata,
    output logic rsp_fault,
    output logic accel_busy,accel_done
);
    typedef enum logic [1:0] {IDLE=0,WAITING=1,RESPONSE=2} state_t;
    state_t state;
    localparam integer COUNT_WIDTH=(LATENCY<2)?1:$clog2(LATENCY+1);
    logic [COUNT_WIDTH-1:0] cycles_left;
    logic saved_write;
    logic [2:0] saved_funct3;
    logic [31:0] saved_addr,saved_wdata;
    logic backend_en,ram_sel,accel_sel,decode_fault,ram_fault,accel_fault,backend_fault;
    logic [4:0] accel_offset;
    logic [31:0] ram_rdata,accel_rdata,backend_rdata;
    assign req_ready=!reset && state==IDLE;
    assign rsp_valid=!reset && state==RESPONSE;
    assign backend_en=!reset && state==WAITING && cycles_left==1;
    address_decoder route (.access_en(backend_en),.addr(saved_addr),.ram_sel(ram_sel),
        .accel_sel(accel_sel),.decode_fault(decode_fault),.accel_offset(accel_offset));
    memory_access #(.WORD_COUNT(16)) ram_target (
        .clk(clk),.reset(reset),.mem_en(ram_sel),.write_en(saved_write),
        .funct3(saved_funct3),.addr(saved_addr),.wdata(saved_wdata),
        .rdata(ram_rdata),.access_fault(ram_fault)
    );
    dotproduct_accelerator accelerator (
        .clk(clk),.reset(reset),.access_en(accel_sel),.write_en(saved_write),
        .funct3(saved_funct3),.offset(accel_offset),.wdata(saved_wdata),
        .rdata(accel_rdata),.access_fault(accel_fault),.busy(accel_busy),.done(accel_done)
    );
    assign backend_fault=decode_fault || ram_fault || accel_fault;
    assign backend_rdata=backend_fault ? 32'd0 : (accel_sel ? accel_rdata : ram_rdata);
    always_ff @(posedge clk) begin
        if(reset) begin
            state<=IDLE;cycles_left<=0;saved_write<=0;saved_funct3<=0;
            saved_addr<=0;saved_wdata<=0;rsp_rdata<=0;rsp_fault<=0;
        end else case(state)
            IDLE: if(req_valid) begin
                saved_write<=req_write;saved_funct3<=req_funct3;
                saved_addr<=req_addr;saved_wdata<=req_wdata;
                cycles_left<=LATENCY;state<=WAITING;
            end
            WAITING: if(cycles_left==1) begin
                // Sample pre-edge read/fault outputs; target writes occur on this edge.
                rsp_rdata<=backend_rdata;rsp_fault<=backend_fault;
                cycles_left<=0;state<=RESPONSE;
            end else cycles_left<=cycles_left-1'b1;
            RESPONSE: if(rsp_ready) state<=IDLE;
            default: state<=IDLE;
        endcase
    end
    // Backend access is a single edge, never repeated while holding a response.
    // START acknowledgement means command accepted, not calculation completed.
    // Reset cancels requests/responses and accelerator work; completed RAM stores persist.
endmodule
