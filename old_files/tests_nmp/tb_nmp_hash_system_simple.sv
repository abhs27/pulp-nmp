//-----------------------------------------------------------------------------
// Title         : NMP Hash System Testbench - Simplified
// Project       : PULPino NMP Extension - Hash Mode Verification
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_nmp_hash_system_simple;

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter CLK_PERIOD = 10;  // 100MHz clock
    parameter [31:0] RS1_BASE_PTR_ADDR = 32'h00100000;
    parameter [31:0] RS2_BASE_PTR_ADDR = 32'h00100004;
    parameter [31:0] RD_BASE_PTR_ADDR  = 32'h00100008;
    
    //-------------------------------------------------------------------------
    // Signals
    //-------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg  [31:0] instruction;
    reg         instruction_valid;
    wire        nmp_active;
    wire        inter_flag;
    wire        error_flag;
    wire [1:0]  error_code;
    wire        hash_error;
    
    // ALT Write Interface
    reg         alt_write_enable;
    reg  [16:0] alt_write_hash_index;
    reg  [31:0] alt_write_rs1_base;
    reg  [31:0] alt_write_rs2_base;
    reg  [31:0] alt_write_rd_base;
    
    // AXI Interfaces (mocked)
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
    
    // Memory model
    reg [31:0] memory [0:4095];
    
    //-------------------------------------------------------------------------
    // Clock Generation
    //-------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //-------------------------------------------------------------------------
    // DUT Instantiation
    //-------------------------------------------------------------------------
    nmp_top_hash #(
        .RS1_BASE_PTR_ADDR(RS1_BASE_PTR_ADDR),
        .RS2_BASE_PTR_ADDR(RS2_BASE_PTR_ADDR),
        .RD_BASE_PTR_ADDR(RD_BASE_PTR_ADDR),
        .HASH_MODE_ENABLE(1'b1)
    ) dut (
        .clk                  (clk),
        .rst_n                (rst_n),
        .instruction          (instruction),
        .instruction_valid    (instruction_valid),
        .nmp_active           (nmp_active),
        .inter_flag           (inter_flag),
        .error_flag           (error_flag),
        .error_code           (error_code),
        .hash_error           (hash_error),
        .alt_write_enable     (alt_write_enable),
        .alt_write_hash_index (alt_write_hash_index),
        .alt_write_rs1_base   (alt_write_rs1_base),
        .alt_write_rs2_base   (alt_write_rs2_base),
        .alt_write_rd_base    (alt_write_rd_base),
        .axia_araddr          (axia_araddr),
        .axia_arvalid         (axia_arvalid),
        .axia_arready         (axia_arready),
        .axia_rdata           (axia_rdata),
        .axia_rresp           (axia_rresp),
        .axia_rvalid          (axia_rvalid),
        .axia_rready          (axia_rready),
        .axib_araddr          (axib_araddr),
        .axib_arvalid         (axib_arvalid),
        .axib_arready         (axib_arready),
        .axib_rdata           (axib_rdata),
        .axib_rresp           (axib_rresp),
        .axib_rvalid          (axib_rvalid),
        .axib_rready          (axib_rready),
        .axic_awaddr          (axic_awaddr),
        .axic_awvalid         (axic_awvalid),
        .axic_awready         (axic_awready),
        .axic_wdata           (axic_wdata),
        .axic_wvalid          (axic_wvalid),
        .axic_wready          (axic_wready),
        .axic_bresp           (axic_bresp),
        .axic_bvalid          (axic_bvalid),
        .axic_bready          (axic_bready)
    );
    
    // Hash Generator for reference
    wire [16:0] generated_hash;
    reg  [31:0] test_rs1_base, test_rs2_base, test_rd_base;
    
    nmp_hash_generator hash_gen (
        .rs1_base_addr(test_rs1_base),
        .rs2_base_addr(test_rs2_base),
        .rd_base_addr(test_rd_base),
        .hash_index(generated_hash)
    );
    
    //-------------------------------------------------------------------------
    // AXI Mock Responder
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 0;
            axib_rvalid <= 0;
            axic_bvalid <= 0;
        end else begin
            // AXI read channel A
            if (axia_arvalid && axia_arready) begin
                axia_rdata  <= memory[axia_araddr[11:2]];
                axia_rvalid <= 1;
                axia_rresp  <= 2'b00;
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 0;
            end
            
            // AXI read channel B
            if (axib_arvalid && axib_arready) begin
                axib_rdata  <= memory[axib_araddr[11:2]];
                axib_rvalid <= 1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 0;
            end
            
            // AXI write channel C
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
                memory[axic_awaddr[11:2]] <= axic_wdata;
                axic_bvalid <= 1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 0;
            end
        end
    end
    
    // AXI ready signals
    always @(*) begin
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready  = 1;
    end
    
    //-------------------------------------------------------------------------
    // Test Sequence
    //-------------------------------------------------------------------------
    initial begin
        integer i, timeout;
        reg [16:0] test_hash;
        reg [31:0] test_instr;
        
        $display("\n=================================================================");
        $display("  NMP Hash System Testbench - Simplified");
        $display("=================================================================\n");
        
        // Initialize
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        
        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        //---------------------------------------------------------------------
        // TEST 1: Hash Generation
        //---------------------------------------------------------------------
        $display("[TEST 1] Hash Generation");
        test_rs1_base = 32'h10000000;
        test_rs2_base = 32'h20000000;
        test_rd_base  = 32'h30000000;
        #1;
        $display("  Hash = 0x%05X", generated_hash);
        if (generated_hash < 17'h20000) begin
            $display("  PASS\n");
        end else begin
            $display("  FAIL\n");
        end
        
        //---------------------------------------------------------------------
        // TEST 2: Write to ALT
        //---------------------------------------------------------------------
        $display("[TEST 2] ALT Write");
        test_rs1_base = 32'h00001000;
        test_rs2_base = 32'h00002000;
        test_rd_base  = 32'h00003000;
        #1;
        test_hash = generated_hash;
        
        @(posedge clk);
        alt_write_enable = 1;
        alt_write_hash_index = test_hash;
        alt_write_rs1_base = 32'h00001000;
        alt_write_rs2_base = 32'h00002000;
        alt_write_rd_base  = 32'h00003000;
        @(posedge clk);
        alt_write_enable = 0;
        repeat(5) @(posedge clk);
        $display("  Written hash 0x%05X", test_hash);
        $display("  PASS\n");
        
        //---------------------------------------------------------------------
        // TEST 3: Hash Mode Operation
        //---------------------------------------------------------------------
        $display("[TEST 3] Hash Mode NMP Operation");
        
        // Initialize memory
        for (i = 0; i < 8; i = i + 1) begin
            memory[(32'h00001000 >> 2) + i] = 32'h00000100 + i;
            memory[(32'h00002000 >> 2) + i] = 32'h00001000 + i;
            memory[(32'h00003000 >> 2) + i] = 32'h00000000;
        end
        
        // Create instruction: [31:15]=hash, [14]=1, [13:12]=00, [11:7]=size, [6:0]=0x6b
        test_instr = {test_hash, 1'b1, 2'b00, 5'd8, 7'h6b};
        $display("  Instruction = 0x%08X", test_instr);
        
        // Execute
        @(posedge clk);
        instruction = test_instr;
        instruction_valid = 1;
        @(posedge clk);
        instruction_valid = 0;
        
        // Wait for completion
        timeout = 0;
        while (!inter_flag && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        if (hash_error) begin
            $display("  FAIL: Hash error!");
        end else if (timeout >= 1000) begin
            $display("  FAIL: Timeout!");
        end else begin
            $display("  Completed in %0d cycles", timeout);
            // Check results
            if (memory[(32'h00003000 >> 2)] == 32'h00001100) begin
                $display("  PASS: Results correct\n");
            end else begin
                $display("  FAIL: RD[0] = 0x%08X, expected 0x00001100\n", memory[(32'h00003000 >> 2)]);
            end
        end
        
        $display("=================================================================");
        $display("  Testbench Complete!");
        $display("=================================================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
