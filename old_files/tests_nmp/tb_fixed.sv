`timescale 1ns / 1ps

module tb_fixed;

    parameter CLK_PERIOD = 10;
    
    reg         clk, rst_n;
    reg  [31:0] instruction;
    reg         instruction_valid;
    wire        nmp_active, inter_flag, hash_error;
    
    reg         alt_write_enable;
    reg  [16:0] alt_write_hash_index;
    reg  [31:0] alt_write_rs1_base, alt_write_rs2_base, alt_write_rd_base;
    
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire        axia_arvalid, axib_arvalid, axic_awvalid;
    wire        axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire        axic_wvalid;
    
    // Changed to reg for proper assignment
    reg         axia_arready, axib_arready, axic_awready, axic_wready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg  [1:0]  axia_rresp, axib_rresp, axic_bresp;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    
    reg [31:0] memory [0:4095];
    integer cycle_count;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    nmp_top_hash #(
        .RS1_BASE_PTR_ADDR(32'h00100000),
        .RS2_BASE_PTR_ADDR(32'h00100004),
        .RD_BASE_PTR_ADDR(32'h00100008),
        .HASH_MODE_ENABLE(1'b1)
    ) dut (
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
    
    // AXI Slave - always ready to accept addresses and data
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_arready <= 1'b1;  // Always ready
            axib_arready <= 1'b1;
            axic_awready <= 1'b1;
            axic_wready  <= 1'b1;
        end
    end
    
    // AXI responder for reads
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 1'b0;
            axib_rvalid <= 1'b0;
            axic_bvalid <= 1'b0;
        end else begin
            // Port A read response
            if (axia_arvalid && axia_arready && !axia_rvalid) begin
                axia_rdata  <= memory[axia_araddr[11:2]];
                axia_rvalid <= 1'b1;
                axia_rresp  <= 2'b00;
                $display("  [AXI-A] READ addr=0x%08X data=0x%08X", axia_araddr, memory[axia_araddr[11:2]]);
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 1'b0;
            end
            
            // Port B read response
            if (axib_arvalid && axib_arready && !axib_rvalid) begin
                axib_rdata  <= memory[axib_araddr[11:2]];
                axib_rvalid <= 1'b1;
                axib_rresp  <= 2'b00;
                $display("  [AXI-B] READ addr=0x%08X data=0x%08X", axib_araddr, memory[axib_araddr[11:2]]);
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 1'b0;
            end
            
            // Port C write response
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready && !axic_bvalid) begin
                memory[axic_awaddr[11:2]] <= axic_wdata;
                axic_bvalid <= 1'b1;
                axic_bresp  <= 2'b00;
                $display("  [AXI-C] WRITE addr=0x%08X data=0x%08X", axic_awaddr, axic_wdata);
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 1'b0;
            end
        end
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else if (nmp_active)
            cycle_count <= cycle_count + 1;
    end
    
    // Monitor
    always @(posedge clk) begin
        if (nmp_active && (cycle_count < 30 || cycle_count % 10 == 0)) begin
            $display("CYC %3d | St=%0d | rs1_rd=%b rs2_rd=%b | AXI-A: arv=%b ardy=%b rrdy=%b rv=%b | AXI-B: arv=%b ardy=%b rrdy=%b rv=%b",
                     cycle_count, dut.current_state, 
                     dut.rs1_read_done, dut.rs2_read_done,
                     axia_arvalid, axia_arready, axia_rready, axia_rvalid,
                     axib_arvalid, axib_arready, axib_rready, axib_rvalid);
        end
    end
    
    initial begin
        integer i;
        reg [16:0] test_hash;
        
        $display("\n=== FIXED TESTBENCH ===\n");
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        cycle_count = 0;
        
        // Initialize ready signals
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready = 1;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        $display("[1] Write hash to ALT");
        test_hash = 17'h12345;
        @(posedge clk);
        alt_write_enable = 1;
        alt_write_hash_index = test_hash;
        alt_write_rs1_base = 32'h00001000;
        alt_write_rs2_base = 32'h00002000;
        alt_write_rd_base  = 32'h00003000;
        @(posedge clk);
        alt_write_enable = 0;
        repeat(3) @(posedge clk);
        
        $display("[2] Initialize memory");
        for (i = 0; i < 8; i = i + 1) begin
            memory[(32'h00001000 >> 2) + i] = 32'h00000100 + i;
            memory[(32'h00002000 >> 2) + i] = 32'h00001000 + i;
            memory[(32'h00003000 >> 2) + i] = 32'h00000000;
        end
        
        $display("[3] Send instruction\n");
        instruction = {test_hash, 1'b1, 2'b00, 5'd8, 7'h6b};
        
        @(posedge clk);
        instruction_valid = 1;
        @(posedge clk);
        instruction_valid = 0;
        
        wait(inter_flag || cycle_count > 200);
        
        repeat(3) @(posedge clk);
        
        if (inter_flag) begin
            $display("\n✓ PASS: Completed in %0d cycles", cycle_count);
            for (i = 0; i < 4; i = i + 1) begin
                $display("  RD[%0d]=0x%08X (expect 0x%08X)", 
                         i, memory[(32'h00003000 >> 2) + i],
                         (32'h00000100 + i) + (32'h00001000 + i));
            end
        end else begin
            $display("\n✗ FAIL: Timeout in state %0d", dut.current_state);
        end
        
        $finish;
    end

endmodule
