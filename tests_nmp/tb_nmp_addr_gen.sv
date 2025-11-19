`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_addr_gen
// Project       : PULPino NMP Extension
// Description   : Verifies the address generation logic for both legacy
//                 pointer loading and element-wise array access.
//-----------------------------------------------------------------------------
module tb_nmp_addr_gen;

    // Parameters
    localparam NUM_RANDOM_TESTS = 100;
    localparam RS1_BASE_PTR_ADDR_GOLDEN = 32'h00100000;
    localparam RS2_BASE_PTR_ADDR_GOLDEN = 32'h00100004;
    localparam RD_BASE_PTR_ADDR_GOLDEN  = 32'h00100008;

    // Testbench signals
    reg  [1:0]  addr_load_counter;
    reg  [4:0]  element_counter;
    reg  [31:0] rs1_base_addr;
    reg  [31:0] rs2_base_addr;
    reg  [31:0] rd_base_addr;

    wire [31:0] base_ptr_addr;
    wire [31:0] rs1_element_addr;
    wire [31:0] rs2_element_addr;
    wire [31:0] rd_element_addr;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate the DUT with default parameters
    nmp_addr_gen dut (
        .clk(1'b0), // clk and rst_n are not used in this module
        .rst_n(1'b1),
        .addr_load_counter(addr_load_counter),
        .element_counter(element_counter),
        .rs1_base_addr(rs1_base_addr),
        .rs2_base_addr(rs2_base_addr),
        .rd_base_addr(rd_base_addr),
        .base_ptr_addr(base_ptr_addr),
        .rs1_element_addr(rs1_element_addr),
        .rs2_element_addr(rs2_element_addr),
        .rd_element_addr(rd_element_addr)
    );

    // Task to run a single test case
    task run_test;
        input [1:0]  t_alc; // addr_load_counter
        input [4:0]  t_ec;  // element_counter
        input [31:0] t_rs1_base, t_rs2_base, t_rd_base;
        input string test_name;
        
        reg [31:0] exp_base_ptr, exp_rs1_elem, exp_rs2_elem, exp_rd_elem;
        reg test_passed;
        begin
            test_count++;
            test_passed = 1'b1;

            // Apply inputs
            addr_load_counter = t_alc;
            element_counter   = t_ec;
            rs1_base_addr     = t_rs1_base;
            rs2_base_addr     = t_rs2_base;
            rd_base_addr      = t_rd_base;

            #1; // Wait for combinational logic

            // Calculate golden values
            case (t_alc)
                2'd0: exp_base_ptr = RS1_BASE_PTR_ADDR_GOLDEN;
                2'd1: exp_base_ptr = RS2_BASE_PTR_ADDR_GOLDEN;
                2'd2: exp_base_ptr = RD_BASE_PTR_ADDR_GOLDEN;
                default: exp_base_ptr = 32'h0;
            endcase
            
            exp_rs1_elem = t_rs1_base + (t_ec << 2);
            exp_rs2_elem = t_rs2_base + (t_ec << 2);
            exp_rd_elem  = t_rd_base  + (t_ec << 2);

            // Check outputs
            if (base_ptr_addr !== exp_base_ptr) begin
                $display("[FAIL] %s: base_ptr_addr mismatch. Expected: %h, Got: %h", test_name, exp_base_ptr, base_ptr_addr);
                test_passed = 1'b0;
            end
            if (rs1_element_addr !== exp_rs1_elem) begin
                $display("[FAIL] %s: rs1_element_addr mismatch. Expected: %h, Got: %h", test_name, exp_rs1_elem, rs1_element_addr);
                test_passed = 1'b0;
            end
            if (rs2_element_addr !== exp_rs2_elem) begin
                $display("[FAIL] %s: rs2_element_addr mismatch. Expected: %h, Got: %h", test_name, exp_rs2_elem, rs2_element_addr);
                test_passed = 1'b0;
            end
            if (rd_element_addr !== exp_rd_elem) begin
                $display("[FAIL] %s: rd_element_addr mismatch. Expected: %h, Got: %h", test_name, exp_rd_elem, rd_element_addr);
                test_passed = 1'b0;
            end

            if (test_passed) begin
                $display("[PASS] %s", test_name);
                pass_count++;
            end else begin
                fail_count++;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("=== Testbench for nmp_addr_gen ===");
        $display("========================================\n");

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");
        
        // Test addr_load_counter
        run_test(2'd0, 5'd0, 32'h1000, 32'h2000, 32'h3000, "Load Counter 0 (RS1 Ptr)");
        run_test(2'd1, 5'd0, 32'h1000, 32'h2000, 32'h3000, "Load Counter 1 (RS2 Ptr)");
        run_test(2'd2, 5'd0, 32'h1000, 32'h2000, 32'h3000, "Load Counter 2 (RD Ptr)");
        run_test(2'd3, 5'd0, 32'h1000, 32'h2000, 32'h3000, "Load Counter 3 (Default)");

        // Test element_counter
        run_test(2'd0, 5'd0,  32'h1000, 32'h2000, 32'h3000, "Element Counter 0");
        run_test(2'd0, 5'd1,  32'h1000, 32'h2000, 32'h3000, "Element Counter 1");
        run_test(2'd0, 5'd15, 32'h1000, 32'h2000, 32'h3000, "Element Counter 15");
        run_test(2'd0, 5'd31, 32'h1000, 32'h2000, 32'h3000, "Element Counter 31 (Max)");

        // Test different base addresses
        run_test(2'd0, 5'd5, 32'h8000_0000, 32'h9000_0000, 32'hA000_0000, "High Base Addresses");
        run_test(2'd0, 5'd10, 32'h0000_0100, 32'h0000_0200, 32'h0000_0300, "Low Base Addresses");

        // --- Randomized Tests ---
        $display("\n--- Running %0d Randomized Tests ---", NUM_RANDOM_TESTS);
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            reg [1:0]  rand_alc;
            reg [4:0]  rand_ec;
            reg [31:0] rand_rs1, rand_rs2, rand_rd;

            rand_alc = $random;
            rand_ec  = $random;
            // Ensure base addresses are word-aligned for realism
            rand_rs1 = {$random, 2'b00};
            rand_rs2 = {$random, 2'b00};
            rand_rd  = {$random, 2'b00};
            
            run_test(rand_alc, rand_ec, rand_rs1, rand_rs2, rand_rd, $sformatf("Random Test %0d", i + 1));
        end

        // --- Test Summary ---
        $display("\n========================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("========================================\n");

        $finish;
    end

endmodule
