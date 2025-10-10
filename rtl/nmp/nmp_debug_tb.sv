`timescale 1ns / 1ps

module nmp_debug_tb;
    parameter CLK_PERIOD = 10;
    
    // Signals
    logic clk, rst_n;
    logic [31:0] instruction;
    logic instruction_valid;
    wire nmp_active, inter_flag;
    wire error_flag;
    wire [1:0] error_code;
    
    // Simplified AXI signals
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr, axic_wdata;
    wire axia_arvalid, axib_arvalid, axic_awvalid, axic_wvalid;
    wire axia_rready, axib_rready, axic_bready;
    
    // DUT
    nmp_unit_top dut (.*,
        .axia_arready(1'b1),
        .axia_rdata(32'h12345678),
        .axia_rresp(2'b00),
        .axia_rvalid(axia_arvalid),
        .axib_arready(1'b1),
        .axib_rdata(32'h87654321),
        .axib_rresp(2'b00),
        .axib_rvalid(axib_arvalid),
        .axic_awready(1'b1),
        .axic_wready(1'b1),
        .axic_bresp(2'b00),
        .axic_bvalid(axic_awvalid & axic_wvalid)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test
    initial begin
        $dumpfile("debug.vcd");
        $dumpvars(0, nmp_debug_tb);
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        @(posedge clk);
        instruction = {7'b0110000, 5'd4, 5'b00000, 3'b000, 5'b00000, 7'b0110011};
        instruction_valid = 1;
        @(posedge clk);
        instruction_valid = 0;
        
        repeat(100) @(posedge clk);
        $display("Test completed. NMP active: %b, Error: %b", nmp_active, error_flag);
        $finish;
    end
endmodule
