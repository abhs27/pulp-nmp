`timescale 1ns / 1ps

module tb_quick_test;
    parameter CLK_PERIOD = 10;
    reg clk, rst_n;
    reg [31:0] instruction;
    reg instruction_valid;
    wire nmp_active, inter_flag, hash_error;
    
    reg alt_write_enable;
    reg [16:0] alt_write_hash_index;
    reg [31:0] alt_write_rs1_base, alt_write_rs2_base, alt_write_rd_base;
    
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire axia_arvalid, axib_arvalid, axic_awvalid;
    reg axia_arready, axib_arready, axic_awready;
    reg [31:0] axia_rdata, axib_rdata;
    reg [1:0] axia_rresp, axib_rresp, axic_bresp;
    reg axia_rvalid, axib_rvalid, axic_bvalid;
    wire axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire axic_wvalid;
    reg axic_wready;
    
    reg [31:0] memory [0:4095];
    
    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end
    
    nmp_top_hash #(.HASH_MODE_ENABLE(1'b1)) dut (
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction), .instruction_valid(instruction_valid),
        .nmp_active(nmp_active), .inter_flag(inter_flag),
        .error_flag(), .error_code(), .hash_error(hash_error),
        .alt_write_enable(alt_write_enable), .alt_write_hash_index(alt_write_hash_index),
        .alt_write_rs1_base(alt_write_rs1_base), .alt_write_rs2_base(alt_write_rs2_base), .alt_write_rd_base(alt_write_rd_base),
        .axia_araddr(axia_araddr), .axia_arvalid(axia_arvalid), .axia_arready(axia_arready),
        .axia_rdata(axia_rdata), .axia_rresp(axia_rresp), .axia_rvalid(axia_rvalid), .axia_rready(axia_rready),
        .axib_araddr(axib_araddr), .axib_arvalid(axib_arvalid), .axib_arready(axib_arready),
        .axib_rdata(axib_rdata), .axib_rresp(axib_rresp), .axib_rvalid(axib_rvalid), .axib_rready(axib_rready),
        .axic_awaddr(axic_awaddr), .axic_awvalid(axic_awvalid), .axic_awready(axic_awready),
        .axic_wdata(axic_wdata), .axic_wvalid(axic_wvalid), .axic_wready(axic_wready),
        .axic_bresp(axic_bresp), .axic_bvalid(axic_bvalid), .axic_bready(axic_bready)
    );
    
    // Simple AXI responder
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 0; axib_rvalid <= 0; axic_bvalid <= 0;
        end else begin
            if (axia_arvalid && axia_arready) begin axia_rdata <= memory[axia_araddr[11:2]]; axia_rvalid <= 1; axia_rresp <= 2'b00; end
            else if (axia_rvalid && axia_rready) axia_rvalid <= 0;
            
            if (axib_arvalid && axib_arready) begin axib_rdata <= memory[axib_araddr[11:2]]; axib_rvalid <= 1; axib_rresp <= 2'b00; end
            else if (axib_rvalid && axib_rready) axib_rvalid <= 0;
            
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin memory[axic_awaddr[11:2]] <= axic_wdata; axic_bvalid <= 1; axic_bresp <= 2'b00; end
            else if (axic_bvalid && axic_bready) axic_bvalid <= 0;
        end
    end
    
    always @(*) begin axia_arready = 1; axib_arready = 1; axic_awready = 1; axic_wready = 1; end
    
    initial begin
        integer i, timeout;
        
        rst_n = 0; instruction = 0; instruction_valid = 0; alt_write_enable = 0;
        #50; rst_n = 1; #20;
        
        // Write to ALT
        @(posedge clk);
        alt_write_enable = 1; alt_write_hash_index = 17'h12345;
        alt_write_rs1_base = 32'h00001000; alt_write_rs2_base = 32'h00002000; alt_write_rd_base = 32'h00003000;
        @(posedge clk);
        alt_write_enable = 0;
        repeat(5) @(posedge clk);
        
        // Init memory
        for (i = 0; i < 8; i = i + 1) begin
            memory[(32'h00001000 >> 2) + i] = 32'h00000100 + i;
            memory[(32'h00002000 >> 2) + i] = 32'h00001000 + i;
        end
        
        // Execute
        instruction = {17'h12345, 1'b1, 2'b00, 5'd8, 7'h6b};
        @(posedge clk); instruction_valid = 1;
        @(posedge clk); instruction_valid = 0;
        
        // Wait MUCH longer
        timeout = 0;
        while (!inter_flag && timeout < 5000) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (timeout % 100 == 0) $display("Waiting... %0d cycles, state=%0d", timeout, dut.current_state);
        end
        
        if (inter_flag) 
            $display("✓ PASS in %0d cycles! Result=0x%08X", timeout, memory[(32'h00003000 >> 2)]);
        else
            $display("✗ FAIL: Timeout at state %0d", dut.current_state);
        
        $finish;
    end
endmodule
