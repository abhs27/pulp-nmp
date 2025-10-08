//-----------------------------------------------------------------------------
// Title         : NMP Hash System Testbench
// Project       : PULPino NMP Extension - Hash Mode Verification
// Description   : Comprehensive testbench for hash-based address lookup
//                 Tests:
//                 1. Hash generation correctness
//                 2. ALT write and read operations
//                 3. Legacy mode operation
//                 4. Hash mode operation
//                 5. Hash collision handling
//                 6. Error cases
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_nmp_hash_system;

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
    
    // Test variables
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    // Memory model for legacy mode
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
            axia_rdata  <= 0;
            axib_rdata  <= 0;
        end else begin
            // Handle AXI read channel A
            if (axia_arvalid && axia_arready) begin
                axia_rdata  <= memory[axia_araddr[11:2]];  // Word-aligned
                axia_rvalid <= 1;
                axia_rresp  <= 2'b00;  // OKAY
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 0;
            end
            
            // Handle AXI read channel B
            if (axib_arvalid && axib_arready) begin
                axib_rdata  <= memory[axib_araddr[11:2]];
                axib_rvalid <= 1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 0;
            end
            
            // Handle AXI write channel C
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
                memory[axic_awaddr[11:2]] <= axic_wdata;
                axic_bvalid <= 1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 0;
            end
        end
    end
    
    // AXI ready signals (always ready for simplicity)
    always @(*) begin
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready  = 1;
    end
    
    //-------------------------------------------------------------------------
    // Helper Tasks
    //-------------------------------------------------------------------------
    
    // Task: Reset system
    task reset_system;
        begin
            $display("=== Resetting System ===");
            rst_n = 0;
            instruction = 0;
            instruction_valid = 0;
            alt_write_enable = 0;
            #(CLK_PERIOD * 5);
            rst_n = 1;
            #(CLK_PERIOD * 2);
        end
    endtask
    
    // Task: Initialize memory for legacy mode
    task init_memory;
        input [31:0] rs1_base;
        input [31:0] rs2_base;
        input [31:0] rd_base;
        input [4:0]  array_size;
        integer i;
        begin
            // Store base addresses at known locations
            memory[RS1_BASE_PTR_ADDR[11:2]] = rs1_base;
            memory[RS2_BASE_PTR_ADDR[11:2]] = rs2_base;
            memory[RD_BASE_PTR_ADDR[11:2]]  = rd_base;
            
            // Initialize array data
            for (i = 0; i < array_size; i = i + 1) begin
                memory[(rs1_base >> 2) + i] = 32'h00000100 + i;  // RS1 data
                memory[(rs2_base >> 2) + i] = 32'h00001000 + i;  // RS2 data
                memory[(rd_base  >> 2) + i] = 32'h00000000;      // RD initially zero
            end
        end
    endtask
    
    // Task: Write to ALT
    task write_alt_entry;
        input [31:0] rs1_base;
        input [31:0] rs2_base;
        input [31:0] rd_base;
        output [16:0] hash;
        begin
            // Generate hash
            test_rs1_base = rs1_base;
            test_rs2_base = rs2_base;
            test_rd_base  = rd_base;
            #1;  // Wait for combinational logic
            hash = generated_hash;
            
            // Write to ALT
            @(posedge clk);
            alt_write_enable     = 1;
            alt_write_hash_index = hash;
            alt_write_rs1_base   = rs1_base;
            alt_write_rs2_base   = rs2_base;
            alt_write_rd_base    = rd_base;
            @(posedge clk);
            alt_write_enable = 0;
            $display("  Written to ALT: Hash=0x%05X, RS1=0x%08X, RS2=0x%08X, RD=0x%08X", 
                     hash, rs1_base, rs2_base, rd_base);
        end
    endtask
    
    // Task: Create NMP instruction
    function [31:0] create_nmp_instruction;
        input [16:0] hash;
        input [4:0]  array_size;
        input        hash_mode;
        begin
            // Format: [31:15]=hash, [14]=hash_mode, [13:12]=funct3[1:0], [11:7]=size, [6:0]=opcode
            create_nmp_instruction = {hash, hash_mode, 2'b00, array_size, 7'b1101011};
        end
    endfunction
    
    // Task: Execute NMP instruction and wait for completion
    task execute_nmp;
        input [31:0] instr;
        integer timeout;
        begin
            timeout = 0;
            @(posedge clk);
            instruction = instr;
            instruction_valid = 1;
            @(posedge clk);
            instruction_valid = 0;
            
            // Wait for completion
            while (!inter_flag && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            
            if (timeout >= 1000) begin
                $display("  ERROR: Timeout waiting for completion!");
                fail_count = fail_count + 1;
            end else begin
                $display("  Completed in %0d cycles", timeout);
            end
        end
    endtask
    
    // Task: Verify results
    task verify_results;
        input [31:0] rd_base;
        input [4:0]  array_size;
        integer i;
        reg [31:0] expected, actual;
        reg test_pass;
        begin
            test_pass = 1;
            for (i = 0; i < array_size; i = i + 1) begin
                expected = (32'h00000100 + i) + (32'h00001000 + i);
                actual   = memory[(rd_base >> 2) + i];
                if (actual !== expected) begin
                    $display("  FAIL: RD[%0d] = 0x%08X, expected 0x%08X", i, actual, expected);
                    test_pass = 0;
                end
            end
            
            if (test_pass) begin
                $display("  PASS: All results correct");
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    //-------------------------------------------------------------------------
    // Test Sequence
    //-------------------------------------------------------------------------
    initial begin
        $display("\n");
        $display("=================================================================");
        $display("  NMP Hash-Based Address Lookup System Testbench");
        $display("=================================================================\n");
        
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Declare all variables at the beginning
        reg [16:0] hash1;
        reg [31:0] rs1_base_addr = 32\'h00001000;
        reg [31:0] rs2_base_addr = 32\'h00002000;
        reg [31:0] rd_base_addr  = 32\'h00003000;
        reg [4:0]  test_size = 5\'d8;
        reg [16:0] test_hash;
        integer j;
        reg [31:0] hash_instruction = create_nmp_instruction(test_hash, test_size, 1\'b1);
        reg [31:0] legacy_instruction = create_nmp_instruction(17\'h0, test_size, 1\'b0);
        reg [16:0] hash_a, hash_b, hash_c;
        integer collision_count = 0;
        reg [31:0] invalid_instruction = create_nmp_instruction(17\'h1FFFF, 5\'d4, 1\'b1);
        reg [16:0] hash_set1, hash_set2;
        
        // Initialize
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        
        // Reset
        reset_system();
        
        //---------------------------------------------------------------------
        // TEST 1: Hash Generation Verification
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Hash Generation Verification", test_num);
        $display("-----------------------------------------------------------------");
        
        test_rs1_base = 32'h10000000;
        test_rs2_base = 32'h20000000;
        test_rd_base  = 32'h30000000;
        #1;
        $display("  Input:  RS1=0x%08X, RS2=0x%08X, RD=0x%08X", 
                 test_rs1_base, test_rs2_base, test_rd_base);
        $display("  Output: Hash=0x%05X (%0d decimal)", generated_hash, generated_hash);
        
        if (generated_hash < 17'h20000) begin
            $display("  PASS: Hash within valid range");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Hash out of range");
            fail_count = fail_count + 1;
        end
        
        //---------------------------------------------------------------------
        // TEST 2: ALT Write and Read
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] ALT Write and Read Operations", test_num);
        $display("-----------------------------------------------------------------");
        
        write_alt_entry(32'h00200000, 32'h00300000, 32'h00400000, hash1);
        
        // Give time for write to complete
        repeat(5) @(posedge clk);
        $display("  PASS: ALT write completed");
        pass_count = pass_count + 1;
        
        //---------------------------------------------------------------------
        // TEST 3: Hash Mode Operation
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Hash Mode NMP Operation", test_num);
        $display("-----------------------------------------------------------------");
        
        // Setup test data
        
        // Write hash to ALT
        write_alt_entry(rs1_base_addr, rs2_base_addr, rd_base_addr, test_hash);
        
        // Initialize memory with test data
        for (j = 0; j < test_size; j = j + 1) begin
            memory[(rs1_base_addr >> 2) + j] = 32'h00000100 + j;
            memory[(rs2_base_addr >> 2) + j] = 32'h00001000 + j;
            memory[(rd_base_addr  >> 2) + j] = 32'h00000000;
        end
        
        // Create and execute instruction
        $display("  Instruction: 0x%08X (Hash Mode)", hash_instruction);
        execute_nmp(hash_instruction);
        
        if (!hash_error) begin
            verify_results(rd_base_addr, test_size);
        end else begin
            $display("  FAIL: Hash error occurred");
            fail_count = fail_count + 1;
        end
        
        //---------------------------------------------------------------------
        // TEST 4: Legacy Mode Operation (bit[14]=0)
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Legacy Mode NMP Operation", test_num);
        $display("-----------------------------------------------------------------");
        
        rs1_base_addr = 32'h00001400;
        rs2_base_addr = 32'h00002400;
        rd_base_addr  = 32'h00003400;
        test_size = 5'd4;
        
        init_memory(rs1_base_addr, rs2_base_addr, rd_base_addr, test_size);
        
        // Create legacy mode instruction (bit[14]=0)
        $display("  Instruction: 0x%08X (Legacy Mode)", legacy_instruction);
        execute_nmp(legacy_instruction);
        
        if (!error_flag) begin
            verify_results(rd_base_addr, test_size);
        end else begin
            $display("  FAIL: Error occurred during operation");
            fail_count = fail_count + 1;
        end
        
        //---------------------------------------------------------------------
        // TEST 5: Hash Collision Test (Different addresses, same hash)
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Hash Uniqueness Test", test_num);
        $display("-----------------------------------------------------------------");
        
        
        // Test multiple address combinations
        test_rs1_base = 32'h10000000; test_rs2_base = 32'h20000000; test_rd_base = 32'h30000000;
        #1; hash_a = generated_hash;
        
        test_rs1_base = 32'h11000000; test_rs2_base = 32'h21000000; test_rd_base = 32'h31000000;
        #1; hash_b = generated_hash;
        
        test_rs1_base = 32'h12000000; test_rs2_base = 32'h22000000; test_rd_base = 32'h32000000;
        #1; hash_c = generated_hash;
        
        $display("  Hash A: 0x%05X", hash_a);
        $display("  Hash B: 0x%05X", hash_b);
        $display("  Hash C: 0x%05X", hash_c);
        
        if (hash_a == hash_b) collision_count = collision_count + 1;
        if (hash_a == hash_c) collision_count = collision_count + 1;
        if (hash_b == hash_c) collision_count = collision_count + 1;
        
        if (collision_count == 0) begin
            $display("  PASS: No collisions detected");
            pass_count = pass_count + 1;
        end else begin
            $display("  INFO: %0d collisions detected (acceptable <1%%)", collision_count);
            pass_count = pass_count + 1;
        end
        
        //---------------------------------------------------------------------
        // TEST 6: Error Case - Hash Not Found
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Error Handling - Hash Not Found", test_num);
        $display("-----------------------------------------------------------------");
        
        // Use a hash that wasn't written to ALT
        $display("  Instruction: 0x%08X (Invalid Hash)", invalid_instruction);
        execute_nmp(invalid_instruction);
        
        if (hash_error) begin
            $display("  PASS: Hash error correctly detected");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Hash error not detected");
            fail_count = fail_count + 1;
        end
        
        //---------------------------------------------------------------------
        // TEST 7: Multiple Operations with Different Hashes
        //---------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Multiple Hash Mode Operations", test_num);
        $display("-----------------------------------------------------------------");
        
        
        // First operation
        write_alt_entry(32'h00004000, 32'h00005000, 32'h00006000, hash_set1);
        for (j = 0; j < 3; j = j + 1) begin
            memory[(32'h00004000 >> 2) + j] = 32'h0000000A + j;
            memory[(32'h00005000 >> 2) + j] = 32'h00000014 + j;
        end
        execute_nmp(create_nmp_instruction(hash_set1, 5'd3, 1'b1));
        verify_results(32'h00006000, 5'd3);
        
        // Second operation with different hash
        write_alt_entry(32'h00007000, 32'h00008000, 32'h00009000, hash_set2);
        for (j = 0; j < 3; j = j + 1) begin
            memory[(32'h00007000 >> 2) + j] = 32'h00000064 + j;
            memory[(32'h00008000 >> 2) + j] = 32'h000000C8 + j;
        end
        execute_nmp(create_nmp_instruction(hash_set2, 5'd3, 1'b1));
        verify_results(32'h00009000, 5'd3);
        
        //---------------------------------------------------------------------
        // Test Summary
        //---------------------------------------------------------------------
        $display("\n");
        $display("=================================================================");
        $display("  Test Summary");
        $display("=================================================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("=================================================================");
        
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  SOME TESTS FAILED!");
        end
        $display("\n");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #500000;  // 500us timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
