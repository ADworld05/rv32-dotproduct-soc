`timescale 1ns/1ps

module tb_regfile;
    logic clk = 1'b0;
    logic reset;
    logic we;
    logic [4:0] waddr, raddr1, raddr2;
    logic [31:0] wdata, rdata1, rdata2;
    int checks = 0;

    regfile dut (
        .clk(clk), .reset(reset), .we(we),
        .waddr(waddr), .wdata(wdata),
        .raddr1(raddr1), .raddr2(raddr2),
        .rdata1(rdata1), .rdata2(rdata2)
    );

    // 10 ns period. Drive inputs away from the active edge, and check
    // after the edge so nonblocking register updates have completed.
    always #5 clk = ~clk;

    task automatic check_reads (
        input logic [31:0] expected1,
        input logic [31:0] expected2
    );
        if (rdata1 !== expected1)
            $fatal(1, "Port 1: x%0d expected=%h actual=%h", raddr1, expected1, rdata1);
        if (rdata2 !== expected2)
            $fatal(1, "Port 2: x%0d expected=%h actual=%h", raddr2, expected2, rdata2);
        checks = checks + 2;
    endtask

    task automatic write_reg (
        input logic [4:0] addr,
        input logic [31:0] data
    );
        @(negedge clk);
        we = 1'b1;
        waddr = addr;
        wdata = data;
        @(posedge clk);
        #1;
        we = 1'b0;
    endtask

    initial begin
        reset = 1'b1;
        we = 1'b0;
        waddr = 5'd0;
        wdata = 32'd0;
        raddr1 = 5'd0;
        raddr2 = 5'd0;
        @(posedge clk);
        #1;
        reset = 1'b0;

        // Reset initializes all stored registers; x0 always reads zero.
        for (int i = 0; i < 32; i++) begin
            raddr1 = i;
            raddr2 = 31 - i;
            #1;
            check_reads(32'd0, 32'd0);
        end

        write_reg(5'd2, 32'd7);
        write_reg(5'd3, 32'd9);
        raddr1 = 5'd2;
        raddr2 = 5'd3;
        #1;
        check_reads(32'd7, 32'd9);

        // A disabled write must leave storage unchanged.
        @(negedge clk);
        we = 1'b0;
        waddr = 5'd2;
        wdata = 32'd99;
        @(posedge clk);
        #1;
        check_reads(32'd7, 32'd9);

        // Reading a location being written: old value before the edge,
        // new value after the edge and its nonblocking update.
        @(negedge clk);
        we = 1'b1;
        waddr = 5'd2;
        wdata = 32'd16;
        #1;
        check_reads(32'd7, 32'd9);
        @(posedge clk);
        #1;
        we = 1'b0;
        check_reads(32'd16, 32'd9);

        write_reg(5'd0, 32'hFFFFFFFF);
        raddr1 = 5'd0;
        raddr2 = 5'd2;
        #1;
        check_reads(32'd0, 32'd16);

        // Both ports may select the same register.
        raddr1 = 5'd3;
        raddr2 = 5'd3;
        #1;
        check_reads(32'd9, 32'd9);

        // Read-address changes select stored values without a clock edge.
        raddr1 = 5'd2;
        raddr2 = 5'd3;
        #1;
        check_reads(32'd16, 32'd9);

        // Exercise every writable address, including x31.
        for (int i = 1; i < 32; i++) begin
            write_reg(i, 32'h1000 + i);
            raddr1 = i;
            raddr2 = 5'd0;
            #1;
            check_reads(32'h1000 + i, 32'd0);
        end

        // Reset must win over a simultaneous write request.
        @(negedge clk);
        reset = 1'b1;
        we = 1'b1;
        waddr = 5'd3;
        wdata = 32'd123;
        @(posedge clk);
        #1;
        reset = 1'b0;
        we = 1'b0;
        for (int i = 0; i < 32; i++) begin
            raddr1 = i;
            raddr2 = 31 - i;
            #1;
            check_reads(32'd0, 32'd0);
        end

        $display("PASS: %0d register-file checks", checks);
        $finish;
    end
endmodule
