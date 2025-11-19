`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_address_lookup_table
// Project       : PULPino NMP Extension
// Description   : Verifies the standard (uncompressed) Address Lookup Table.
//-----------------------------------------------------------------------------
module tb_nmp_address_lookup_table;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam NUM_RANDOM_TESTS = 50;

    // DUT Interface
    reg         clk = 0;
    reg         rst_n;
    reg         write_enable;
    reg  [16:0] write_hash_index;
    reg  [31:0] write_rs1_base;
    reg  [31:0] write_rs2_base;
    reg  [31:0] write_rd_base;
    reg         read_enable;
    reg  [16:0] read_hash_index;
    wire [31:0] read_rs1_base;
    wire [31:0] read_rs2_base;
    wire [31:0] read_rd_base;
    wire        read_valid;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate DUT
    nmp_address_lookup_table dut (
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
        .read_valid(read_valid)
    );

    // Clock generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task to write an entry
    task write_entry(input [16:0] hash, input [31:0] rs1, input [31:0] rs2, input [31:0] rd);
        @(posedge clk);
        write_enable = 1'b1;
        write_hash_index = hash;
        write_rs1_base = rs1;
        write_rs2_base = rs2;
        write_rd_base = rd;
        @(posedge clk);
        write_enable = 1'b0;
    endtask

    // Helper task to read an entry and check the result
    task read_and_check_entry(input [16:0] hash, input [31:0] exp_rs1, input [31:0] exp_rs2, input [31:0] exp_rd, input exp_valid, input string test_name);
        test_count++;
        
        // Start the read
        @(posedge clk);
        read_enable = 1'b1;
        read_hash_index = hash;
        
        // DUT has registered outputs, so they will be valid on the next clock edge.
        @(posedge clk);
        
        // Check the results on the cycle where they are valid
        if (read_rs1_base === exp_rs1 && read_rs2_base === exp_rs2 && read_rd_base === exp_rd && read_valid === exp_valid) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s", test_name);
            $display("       Expected: rs1=%h, rs2=%h, rd=%h, valid=%b", exp_rs1, exp_rs2, exp_rd, exp_valid);
            $display("       Got:      rs1=%h, rs2=%h, rd=%h, valid=%b", read_rs1_base, read_rs2_base, read_rd_base, read_valid);
            fail_count++;
        end
        
        // De-assert read enable for the next cycle
        read_enable = 1'b0;
    endtask

    // Main test sequence
    initial begin
        $display("\n=================================================");
        $display("=== Testbench for nmp_address_lookup_table ===");
        $display("=================================================\n");

        // Reset the DUT
        rst_n = 1'b0;
        write_enable = 1'b0;
        read_enable = 1'b0;
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        @(posedge clk);

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");

        // Test 1: Basic write and read
        write_entry(17'h00001, 32'h1000_0000, 32'h2000_0000, 32'h3000_0000);
        read_and_check_entry(17'h00001, 32'h1000_0000, 32'h2000_0000, 32'h3000_0000, 1'b1, "Basic Write and Read");

        // Test 2: Read an uninitialized entry
        read_and_check_entry(17'h00002, 32'h0, 32'h0, 32'h0, 1'b0, "Read Uninitialized Entry");

        // Test 3: Overwrite an existing entry
        write_entry(17'h00001, 32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC);
        read_and_check_entry(17'h00001, 32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC, 1'b1, "Overwrite Existing Entry");

        // Test 4: Test boundary hash indices
        write_entry(17'h00000, 32'h01010101, 32'h02020202, 32'h03030303);
        read_and_check_entry(17'h00000, 32'h01010101, 32'h02020202, 32'h03030303, 1'b1, "Boundary Index 0");

        write_entry(17'h1FFFF, 32'hF1F1F1F1, 32'hF2F2F2F2, 32'hF3F3F3F3);
        read_and_check_entry(17'h1FFFF, 32'hF1F1F1F1, 32'hF2F2F2F2, 32'hF3F3F3F3, 1'b1, "Boundary Index 131071");

        // --- Randomized Tests ---
        $display("\n--- Running %0d Randomized Tests ---", NUM_RANDOM_TESTS);
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            reg [16:0] rand_hash;
            reg [31:0] rand_rs1, rand_rs2, rand_rd;

            rand_hash = $random;
            rand_rs1 = $random;
            rand_rs2 = $random;
            rand_rd = $random;

            write_entry(rand_hash, rand_rs1, rand_rs2, rand_rd);
            read_and_check_entry(rand_hash, rand_rs1, rand_rs2, rand_rd, 1'b1, $sformatf("Random Test %0d", i + 1));
        end

        // --- Test Summary ---
        $display("\n=================================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("=================================================\n");

        $finish;
    end

endmodule
