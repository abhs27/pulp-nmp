//-----------------------------------------------------------------------------
// Title         : Testbench for Compressed Address Lookup Table
// Project       : PULPino NMP Extension - Base+Offset Encoding
// Description   : Comprehensive testbench for compressed ALT module
//                 Tests: compression, decompression, overflow detection,
//                        various offset sizes, and edge cases
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_nmp_alt_compressed;

    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Write Interface
    reg        write_enable;
    reg [16:0] write_hash_index;
    reg [31:0] write_rs1_base;
    reg [31:0] write_rs2_base;
    reg [31:0] write_rd_base;
    
    // Read Interface
    reg        read_enable;
    reg [16:0] read_hash_index;
    wire [31:0] read_rs1_base;
    wire [31:0] read_rs2_base;
    wire [31:0] read_rd_base;
    wire        read_valid;
    wire        offset_overflow_error;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    //-------------------------------------------------------------------------
    // Instantiate DUT with 16-bit offsets
    //-------------------------------------------------------------------------
    nmp_address_lookup_table_compressed #(
        .OFFSET_BITS(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(write_enable),
        .write_hash_index(write_hash_index),
        .write_rs1_base(write_rs1_base),
        .write_rs2_base(write_rs2_base),
        .write_rd_base(write_rd_base),
        .read_enable(read_enable),
        .read_hash_index(read_hash_index),
        .read_rs1_base(read_rs1_base),
        .read_rs2_base(read_rs2_base),
        .read_rd_base(read_rd_base),
        .read_valid(read_valid),
        .offset_overflow_error(offset_overflow_error)
    );
    
    //-------------------------------------------------------------------------
    // Clock Generation (100MHz)
    //-------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //-------------------------------------------------------------------------
    // Task: Write Entry
    //-------------------------------------------------------------------------
    task write_entry(
        input [16:0] hash_idx,
        input [31:0] rs1,
        input [31:0] rs2,
        input [31:0] rd
    );
    begin
        @(posedge clk);
        write_enable = 1;
        write_hash_index = hash_idx;
        write_rs1_base = rs1;
        write_rs2_base = rs2;
        write_rd_base = rd;
        @(posedge clk);
        write_enable = 0;
        @(posedge clk);
    end
    endtask
    
    //-------------------------------------------------------------------------
    // Task: Read Entry
    //-------------------------------------------------------------------------
    task read_entry(
        input [16:0] hash_idx
    );
    begin
        @(posedge clk);
        read_enable = 1;
        read_hash_index = hash_idx;
        @(posedge clk);
        read_enable = 0;
        @(posedge clk);  // Wait one more cycle for output to be registered
    end
    endtask
    
    //-------------------------------------------------------------------------
    // Task: Check Result
    //-------------------------------------------------------------------------
    task check_result(
        input [31:0] expected_rs1,
        input [31:0] expected_rs2,
        input [31:0] expected_rd,
        input        expected_valid,
        input        expected_overflow,
        input string test_name
    );
    begin
        test_count = test_count + 1;
        if (read_rs1_base == expected_rs1 && 
            read_rs2_base == expected_rs2 && 
            read_rd_base == expected_rd &&
            read_valid == expected_valid &&
            offset_overflow_error == expected_overflow) begin
            $display("[PASS] Test %0d: %s", test_count, test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: %s", test_count, test_name);
            $display("       Expected: rs1=%08x, rs2=%08x, rd=%08x, valid=%0b, overflow=%0b",
                     expected_rs1, expected_rs2, expected_rd, expected_valid, expected_overflow);
            $display("       Got:      rs1=%08x, rs2=%08x, rd=%08x, valid=%0b, overflow=%0b",
                     read_rs1_base, read_rs2_base, read_rd_base, read_valid, offset_overflow_error);
            fail_count = fail_count + 1;
        end
    end
    endtask
    
    //-------------------------------------------------------------------------
    // Main Test Sequence
    //-------------------------------------------------------------------------
    initial begin
        // Initialize
        $display("============================================================");
        $display("Compressed ALT Testbench - Base+Offset Encoding (16-bit)");
        $display("============================================================");
        
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Reset
        rst_n = 0;
        write_enable = 0;
        read_enable = 0;
        write_hash_index = 0;
        write_rs1_base = 0;
        write_rs2_base = 0;
        write_rd_base = 0;
        read_hash_index = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        //---------------------------------------------------------------------
        // TEST 1: Basic Compression - Small Offsets (4KB apart)
        //---------------------------------------------------------------------
        $display("\n--- TEST 1: Small Offsets (4KB apart) ---");
        write_entry(17'h00001, 32'h10000000, 32'h10001000, 32'h10002000);
        read_entry(17'h00001);
        check_result(32'h10000000, 32'h10001000, 32'h10002000, 1'b1, 1'b0, "Small offsets +4KB");
        
        //---------------------------------------------------------------------
        // TEST 2: Medium Offsets (64KB apart)
        //---------------------------------------------------------------------
        $display("\n--- TEST 2: Medium Offsets (64KB apart) ---");
        write_entry(17'h00002, 32'h20000000, 32'h20010000, 32'h20020000);
        read_entry(17'h00002);
        check_result(32'h20000000, 32'h20010000, 32'h20020000, 1'b1, 1'b0, "Medium offsets +64KB");
        
        //---------------------------------------------------------------------
        // TEST 3: Large Offsets (128KB apart - within range)
        //---------------------------------------------------------------------
        $display("\n--- TEST 3: Large Offsets (128KB apart) ---");
        write_entry(17'h00003, 32'h30000000, 32'h30020000, 32'h30040000);
        read_entry(17'h00003);
        check_result(32'h30000000, 32'h30020000, 32'h30040000, 1'b1, 1'b0, "Large offsets 128KB");
        
        //---------------------------------------------------------------------
        // TEST 4: Negative Offsets (rs2/rd before rs1)
        //---------------------------------------------------------------------
        $display("\n--- TEST 4: Negative Offsets ---");
        write_entry(17'h00004, 32'h40010000, 32'h40008000, 32'h40000000);
        read_entry(17'h00004);
        check_result(32'h40010000, 32'h40008000, 32'h40000000, 1'b1, 1'b0, "Negative offsets");
        
        //---------------------------------------------------------------------
        // TEST 5: Mixed Offsets (positive and negative)
        //---------------------------------------------------------------------
        $display("\n--- TEST 5: Mixed Offsets ---");
        write_entry(17'h00005, 32'h50008000, 32'h50000000, 32'h50010000);
        read_entry(17'h00005);
        check_result(32'h50008000, 32'h50000000, 32'h50010000, 1'b1, 1'b0, "Mixed +/- offsets");
        
        //---------------------------------------------------------------------
        // TEST 6: Zero Offsets (all same address)
        //---------------------------------------------------------------------
        $display("\n--- TEST 6: Zero Offsets ---");
        write_entry(17'h00006, 32'h60000000, 32'h60000000, 32'h60000000);
        read_entry(17'h00006);
        check_result(32'h60000000, 32'h60000000, 32'h60000000, 1'b1, 1'b0, "Zero offsets");
        
        //---------------------------------------------------------------------
        // TEST 7: Overflow Detection - Offset too large (>128KB = 32768)
        //---------------------------------------------------------------------
        $display("\n--- TEST 7: Overflow Detection (>128KB) ---");
        write_entry(17'h00007, 32'h70000000, 32'h70100000, 32'h70200000);
        @(posedge clk);
        @(posedge clk);
        if (offset_overflow_error) begin
            $display("[PASS] Test %0d: Overflow correctly detected for 1MB offset", test_count+1);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Overflow NOT detected for 1MB offset", test_count+1);
            fail_count = fail_count + 1;
        end
        test_count = test_count + 1;
        
        //---------------------------------------------------------------------
        // TEST 8: Read Non-existent Entry
        //---------------------------------------------------------------------
        $display("\n--- TEST 8: Read Non-existent Entry ---");
        read_entry(17'h0FFFF);
        check_result(32'h00000000, 32'h00000000, 32'h00000000, 1'b0, 1'b0, "Non-existent entry");
        
        //---------------------------------------------------------------------
        // TEST 9: Overwrite Existing Entry
        //---------------------------------------------------------------------
        $display("\n--- TEST 9: Overwrite Entry ---");
        write_entry(17'h00001, 32'h80000000, 32'h80002000, 32'h80004000);
        read_entry(17'h00001);
        check_result(32'h80000000, 32'h80002000, 32'h80004000, 1'b1, 1'b0, "Overwritten entry");
        
        //---------------------------------------------------------------------
        // TEST 10: Maximum Positive Offset (+32767 bytes = ~32KB)
        //---------------------------------------------------------------------
        $display("\n--- TEST 10: Maximum Positive Offset ---");
        write_entry(17'h0000A, 32'h90000000, 32'h90007FFF, 32'h90007FFF);
        read_entry(17'h0000A);
        check_result(32'h90000000, 32'h90007FFF, 32'h90007FFF, 1'b1, 1'b0, "Max positive offset");
        
        //---------------------------------------------------------------------
        // TEST 11: Maximum Negative Offset (-32768 bytes = ~-32KB)
        //---------------------------------------------------------------------
        $display("\n--- TEST 11: Maximum Negative Offset ---");
        write_entry(17'h0000B, 32'hA0008000, 32'hA0000000, 32'hA0000000);
        read_entry(17'h0000B);
        check_result(32'hA0008000, 32'hA0000000, 32'hA0000000, 1'b1, 1'b0, "Max negative offset");
        
        //---------------------------------------------------------------------
        // TEST 12: Sequential Addresses (consecutive allocation)
        //---------------------------------------------------------------------
        $display("\n--- TEST 12: Sequential Addresses ---");
        write_entry(17'h0000C, 32'hB0000000, 32'hB0000100, 32'hB0000200);
        read_entry(17'h0000C);
        check_result(32'hB0000000, 32'hB0000100, 32'hB0000200, 1'b1, 1'b0, "Sequential 256-byte spacing");
        
        //---------------------------------------------------------------------
        // Print Summary
        //---------------------------------------------------------------------
        $display("\n============================================================");
        $display("TEST SUMMARY");
        $display("============================================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\n✅ ALL TESTS PASSED!");
        end else begin
            $display("\n❌ SOME TESTS FAILED!");
        end
        $display("============================================================\n");
        
        // Finish
        #100;
        $finish;
    end
    
    //-------------------------------------------------------------------------
    // Timeout Watchdog
    //-------------------------------------------------------------------------
    initial begin
        #50000;  // 50us timeout
        $display("\n⚠️  TIMEOUT: Test did not complete in time!");
        $finish;
    end

endmodule
