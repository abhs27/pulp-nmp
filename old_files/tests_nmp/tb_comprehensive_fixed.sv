`timescale 1ns / 1ps

module tb_comprehensive_fixed;

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
    
    reg         axia_arready, axib_arready, axic_awready, axic_wready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg  [1:0]  axia_rresp, axib_rresp, axic_bresp;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    
    reg [31:0] memory [0:4095];
    integer cycle_count;
    integer test_count, pass_count, fail_count;
    
    // Use unique hash for each test
    integer hash_counter;
    
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
    
    // AXI Slave
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axia_arready <= 1'b1;
            axib_arready <= 1'b1;
            axic_awready <= 1'b1;
            axic_wready  <= 1'b1;
        end
    end
    
    // AXI responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axia_rvalid <= 1'b0;
            axib_rvalid <= 1'b0;
            axic_bvalid <= 1'b0;
            axia_rdata  <= 32'h0;
            axib_rdata  <= 32'h0;
        end else begin
            if (axia_arvalid && axia_arready && !axia_rvalid) begin
                axia_rdata  <= memory[axia_araddr >> 2];
                axia_rvalid <= 1'b1;
                axia_rresp  <= 2'b00;
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 1'b0;
            end
            
            if (axib_arvalid && axib_arready && !axib_rvalid) begin
                axib_rdata  <= memory[axib_araddr >> 2];
                axib_rvalid <= 1'b1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 1'b0;
            end
            
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready && !axic_bvalid) begin
                memory[axic_awaddr >> 2] <= axic_wdata;
                axic_bvalid <= 1'b1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_count <= 0;
        else if (nmp_active)
            cycle_count <= cycle_count + 1;
    end
    
    // Task to initialize memory - use separate regions for each test
    task init_memory;
        input [31:0] rs1_base, rs2_base, rd_base;
        input [31:0] rs1_pattern, rs2_pattern;
        input [4:0] size;
        integer i;
        begin
            // Clear the entire memory region for this test
            for (i = 0; i < 32; i = i + 1) begin
                memory[(rs1_base >> 2) + i] = 32'h0;
                memory[(rs2_base >> 2) + i] = 32'h0;
                memory[(rd_base >> 2) + i] = 32'h0;
            end
            
            // Initialize only required elements
            for (i = 0; i < size; i = i + 1) begin
                memory[(rs1_base >> 2) + i] = rs1_pattern + i;
                memory[(rs2_base >> 2) + i] = rs2_pattern + i;
            end
        end
    endtask
    
    // Task to verify results
    task verify_results;
        input [31:0] rs1_base, rs2_base, rd_base;
        input [4:0] size;
        input [127:0] test_name;
        integer i, errors;
        reg [31:0] expected, actual, rs1_val, rs2_val;
        begin
            test_count = test_count + 1;
            errors = 0;
            
            for (i = 0; i < size; i = i + 1) begin
                rs1_val = memory[(rs1_base >> 2) + i];
                rs2_val = memory[(rs2_base >> 2) + i];
                expected = rs1_val + rs2_val;
                actual = memory[(rd_base >> 2) + i];
                
                if (actual !== expected) begin
                    if (errors == 0) begin
                        $display("  FAIL: %s", test_name);
                        $display("    Size=%0d, Cycles=%0d", size, cycle_count);
                    end
                    $display("    [%0d] RS1=0x%08X RS2=0x%08X Expected=0x%08X Got=0x%08X", 
                             i, rs1_val, rs2_val, expected, actual);
                    errors = errors + 1;
                end
            end
            
            if (errors == 0) begin
                $display("  PASS: %s (size=%0d, cycles=%0d)", test_name, size, cycle_count);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Task to write hash entry
    task write_hash;
        input [16:0] hash;
        input [31:0] rs1_base, rs2_base, rd_base;
        begin
            @(posedge clk);
            alt_write_enable = 1;
            alt_write_hash_index = hash;
            alt_write_rs1_base = rs1_base;
            alt_write_rs2_base = rs2_base;
            alt_write_rd_base  = rd_base;
            @(posedge clk);
            alt_write_enable = 0;
            repeat(3) @(posedge clk);
        end
    endtask
    
    // Task to run test - uses unique hash each time
    task run_test;
        input [127:0] test_name;
        input [4:0] size;
        input [31:0] rs1_offset, rs2_offset, rd_offset;  // Offsets from base
        input [31:0] rs1_pattern, rs2_pattern;
        reg [16:0] test_hash;
        reg [31:0] rs1_base, rs2_base, rd_base;
        begin
            // Generate unique hash for this test
            test_hash = hash_counter[16:0];
            hash_counter = hash_counter + 1;
            
            // Calculate actual addresses (use different memory regions)
            rs1_base = 32'h00001000 + (rs1_offset << 7);  // Each test gets 128-byte region
            rs2_base = 32'h00002000 + (rs2_offset << 7);
            rd_base  = 32'h00003000 + (rd_offset << 7);
            
            // Initialize memory
            init_memory(rs1_base, rs2_base, rd_base, rs1_pattern, rs2_pattern, size);
            
            // Write hash entry
            write_hash(test_hash, rs1_base, rs2_base, rd_base);
            
            // Execute instruction
            cycle_count = 0;
            instruction = {test_hash, 1'b1, 2'b00, size, 7'h6b};
            @(posedge clk);
            instruction_valid = 1;
            @(posedge clk);
            instruction_valid = 0;
            
            // Wait for completion
            wait(inter_flag || cycle_count > 500);
            repeat(2) @(posedge clk);
            
            if (inter_flag) begin
                verify_results(rs1_base, rs2_base, rd_base, size, test_name);
            end else begin
                test_count = test_count + 1;
                fail_count = fail_count + 1;
                $display("  TIMEOUT: %s (size=%0d, hash=0x%05X)", test_name, size, test_hash);
            end
        end
    endtask
    
    initial begin
        $display("\n========================================================");
        $display("=== COMPREHENSIVE NMP HASH SYSTEM TEST SUITE ===");
        $display("========================================================\n");
        
        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        hash_counter = 1;
        
        // Clear memory
        for (integer i = 0; i < 4096; i = i + 1) memory[i] = 32'h0;
        
        // Reset
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        cycle_count = 0;
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready = 1;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        $display("--- Test Category 1: Different Array Sizes ---");
        run_test("Size 1 element",    5'd1,  0, 0, 0, 32'h00000100, 32'h00001000);
        run_test("Size 2 elements",   5'd2,  1, 1, 1, 32'h00000200, 32'h00002000);
        run_test("Size 4 elements",   5'd4,  2, 2, 2, 32'h00000300, 32'h00003000);
        run_test("Size 8 elements",   5'd8,  3, 3, 3, 32'h00000400, 32'h00004000);
        run_test("Size 16 elements",  5'd16, 4, 4, 4, 32'h00000500, 32'h00005000);
        run_test("Size 31 elements",  5'd31, 5, 5, 5, 32'h00000600, 32'h00006000);
        
        $display("\n--- Test Category 2: Different Data Patterns ---");
        run_test("All zeros",         5'd4,  6, 6, 6, 32'h00000000, 32'h00000000);
        run_test("Small numbers",     5'd4,  7, 7, 7, 32'h00000001, 32'h00000002);
        run_test("Large numbers",     5'd4,  8, 8, 8, 32'hFFFF0000, 32'h0000FFFF);
        run_test("Max values",        5'd2,  9, 9, 9, 32'hFFFFFFFF, 32'h00000001);
        run_test("Alternating bits",  5'd4, 10,10,10, 32'hAAAAAAAA, 32'h55555555);
        
        $display("\n--- Test Category 3: Edge Cases ---");
        run_test("Min size (1)",      5'd1, 11,11,11, 32'h00000001, 32'h00000001);
        run_test("Power of 2 (16)",   5'd16,12,12,12, 32'h00000010, 32'h00000020);
        run_test("Odd size (7)",      5'd7, 13,13,13, 32'h00000070, 32'h00000700);
        run_test("Odd size (15)",     5'd15,14,14,14, 32'h000000F0, 32'h00000F00);
        run_test("Odd size (3)",      5'd3, 15,15,15, 32'h00000030, 32'h00000300);
        run_test("Odd size (5)",      5'd5, 16,16,16, 32'h00000050, 32'h00000500);
        
        $display("\n--- Test Category 4: Sequential Operations ---");
        run_test("Sequential op 1",   5'd3, 17,17,17, 32'h00000010, 32'h00000100);
        run_test("Sequential op 2",   5'd3, 18,18,18, 32'h00000020, 32'h00000200);
        run_test("Sequential op 3",   5'd3, 19,19,19, 32'h00000030, 32'h00000300);
        run_test("Sequential op 4",   5'd3, 20,20,20, 32'h00000040, 32'h00000400);
        
        // Print summary
        $display("\n========================================================");
        $display("=== TEST SUMMARY ===");
        $display("========================================================");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Pass Rate:    %0d%%", (pass_count * 100) / test_count);
        $display("========================================================");
        
        if (fail_count == 0) begin
            $display("\n🎉 ALL TESTS PASSED! System is fully functional.");
        end else begin
            $display("\n⚠️  Some tests failed. Review results above.");
        end
        
        $display("\n");
        $finish;
    end

endmodule
