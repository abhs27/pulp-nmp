//-----------------------------------------------------------------------------
// Debug Testbench - Traces FSM states and signals
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_nmp_hash_debug;

    parameter CLK_PERIOD = 10;
    
    reg         clk;
    reg         rst_n;
    reg  [31:0] instruction;
    reg         instruction_valid;
    wire        nmp_active;
    wire        inter_flag;
    wire        hash_error;
    
    reg         alt_write_enable;
    reg  [16:0] alt_write_hash_index;
    reg  [31:0] alt_write_rs1_base;
    reg  [31:0] alt_write_rs2_base;
    reg  [31:0] alt_write_rd_base;
    
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire        axia_arvalid, axib_arvalid, axic_awvalid;
    reg         axia_arready, axib_arready, axic_awready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg  [1:0]  axia_rresp, axib_rresp, axic_bresp;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    wire        axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire        axic_wvalid;
    reg         axic_wready;
    
    reg [31:0] memory [0:4095];
    
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
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .nmp_active(nmp_active),
        .inter_flag(inter_flag),
        .error_flag(),
        .error_code(),
        .hash_error(hash_error),
        .alt_write_enable(alt_write_enable),
        .alt_write_hash_index(alt_write_hash_index),
        .alt_write_rs1_base(alt_write_rs1_base),
        .alt_write_rs2_base(alt_write_rs2_base),
        .alt_write_rd_base(alt_write_rd_base),
        .axia_araddr(axia_araddr), .axia_arvalid(axia_arvalid), .axia_arready(axia_arready),
        .axia_rdata(axia_rdata), .axia_rresp(axia_rresp), .axia_rvalid(axia_rvalid), .axia_rready(axia_rready),
        .axib_araddr(axib_araddr), .axib_arvalid(axib_arvalid), .axib_arready(axib_arready),
        .axib_rdata(axib_rdata), .axib_rresp(axib_rresp), .axib_rvalid(axib_rvalid), .axib_rready(axib_rready),
        .axic_awaddr(axic_awaddr), .axic_awvalid(axic_awvalid), .axic_awready(axic_awready),
        .axic_wdata(axic_wdata), .axic_wvalid(axic_wvalid), .axic_wready(axic_wready),
        .axic_bresp(axic_bresp), .axic_bvalid(axic_bvalid), .axic_bready(axic_bready)
    );
    
    // AXI responder
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 0;
            axib_rvalid <= 0;
            axic_bvalid <= 0;
        end else begin
            if (axia_arvalid && axia_arready) begin
                axia_rdata  <= memory[axia_araddr[11:2]];
                axia_rvalid <= 1;
                axia_rresp  <= 2'b00;
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 0;
            end
            
            if (axib_arvalid && axib_arready) begin
                axib_rdata  <= memory[axib_araddr[11:2]];
                axib_rvalid <= 1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 0;
            end
            
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
                memory[axic_awaddr[11:2]] <= axic_wdata;
                axic_bvalid <= 1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 0;
            end
        end
    end
    
    always @(*) begin
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready  = 1;
    end
    
    // Monitor FSM state
    always @(posedge clk) begin
        if (nmp_active) begin
            $display("Time=%0t: FSM_STATE=%0d, use_hash_mode=%b, hash_addr_valid=%b, hash_addr_not_found=%b", 
                     $time, dut.current_state, dut.use_hash_mode, 
                     dut.hash_addr_valid, dut.hash_addr_not_found);
        end
    end
    
    initial begin
        integer i;
        reg [16:0] test_hash;
        
        $display("\n=== DEBUG TESTBENCH ===\n");
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Use addresses that DON'T XOR to zero
        $display("[1] Writing to ALT with non-zero hash...");
        test_hash = 17'h12345;  // Manually set a non-zero hash
        
        @(posedge clk);
        alt_write_enable = 1;
        alt_write_hash_index = test_hash;
        alt_write_rs1_base = 32'h00001000;
        alt_write_rs2_base = 32'h00002000;
        alt_write_rd_base  = 32'h00003000;
        @(posedge clk);
        alt_write_enable = 0;
        
        $display("    Written: hash=0x%05X", test_hash);
        repeat(5) @(posedge clk);
        
        // Initialize memory
        $display("[2] Initializing memory...");
        for (i = 0; i < 8; i = i + 1) begin
            memory[(32'h00001000 >> 2) + i] = 32'h00000100 + i;
            memory[(32'h00002000 >> 2) + i] = 32'h00001000 + i;
            memory[(32'h00003000 >> 2) + i] = 32'h00000000;
        end
        
        // Create instruction with the hash we wrote
        instruction = {test_hash, 1'b1, 2'b00, 5'd8, 7'h6b};
        $display("[3] Executing instruction: 0x%08X", instruction);
        $display("    hash_index=0x%05X, hash_mode=1, size=8", test_hash);
        
        @(posedge clk);
        instruction_valid = 1;
        @(posedge clk);
        instruction_valid = 0;
        
        // Wait and watch
        repeat(100) @(posedge clk);
        
        if (inter_flag) begin
            $display("[4] PASS: Operation completed!");
            $display("    Result: RD[0]=0x%08X (expected 0x00001100)", memory[(32'h00003000 >> 2)]);
        end else begin
            $display("[4] FAIL: Timeout - FSM stuck in state %0d", dut.current_state);
        end
        
        $finish;
    end
    
    initial begin
        #50000;
        $display("ERROR: Watchdog timeout!");
        $finish;
    end

endmodule
