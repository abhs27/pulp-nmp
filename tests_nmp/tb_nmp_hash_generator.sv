`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_hash_generator
// Project       : PULPino NMP Extension
// Description   : Verifies the combinational hash generation logic.
//-----------------------------------------------------------------------------
module tb_nmp_hash_generator;

    // Parameters
    localparam NUM_RANDOM_TESTS = 100;

    // Testbench signals
    reg  [31:0] rs1_base_addr;
    reg  [31:0] rs2_base_addr;
    reg  [31:0] rd_base_addr;
    wire [16:0] hash_index;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate the DUT
    nmp_hash_generator dut (
        .rs1_base_addr(rs1_base_addr),
        .rs2_base_addr(rs2_base_addr),
        .rd_base_addr(rd_base_addr),
        .hash_index(hash_index)
    );

    // Golden model to calculate the expected hash
    function automatic [16:0] golden_hash_generator;
        input [31:0] r1, r2, r3;
        localparam [31:0] GOLDEN_RATIO = 32'h9E3779B9;
        logic [31:0] combined;
        logic [31:0] mixed;
        begin
            combined = r1 ^ r2 ^ r3;
            mixed = combined * GOLDEN_RATIO;
            golden_hash_generator = mixed[31:15];
        end
    endfunction

    // Task to run a single test case
    task run_test;
        input [31:0] t_rs1, t_rs2, t_rd;
        input string test_name;
        reg [16:0] expected_hash;
        begin
            test_count++;
            rs1_base_addr = t_rs1;
            rs2_base_addr = t_rs2;
            rd_base_addr  = t_rd;

            #1; // Wait for combinational logic to settle

            expected_hash = golden_hash_generator(t_rs1, t_rs2, t_rd);

            if (hash_index === expected_hash) begin
                $display("[PASS] %s (rs1: %h, rs2: %h, rd: %h) -> hash: %h", test_name, t_rs1, t_rs2, t_rd, hash_index);
                pass_count++;
            end else begin
                $display("[FAIL] %s (rs1: %h, rs2: %h, rd: %h)", test_name, t_rs1, t_rs2, t_rd);
                $display("       Expected hash: %h, Got: %h", expected_hash, hash_index);
                fail_count++;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n=============================================");
        $display("=== Testbench for nmp_hash_generator ===");
        $display("=============================================\n");

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");
        run_test(32'h00000000, 32'h00000000, 32'h00000000, "All Zeros");
        run_test(32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, "All Ones");
        run_test(32'h10000000, 32'h20000000, 32'h30000000, "Typical Addresses 1");
        run_test(32'h80001000, 32'h80002000, 32'h80003000, "Typical Addresses 2");
        run_test(32'h00000001, 32'h00000002, 32'h00000003, "Small Numbers");
        run_test(32'hFFFFFFFF, 32'h00000000, 32'hFFFFFFFF, "Symmetric XOR");
        run_test(32'h12345678, 32'h87654321, 32'hABCDEF01, "Arbitrary Values");

        // --- Randomized Tests ---
        $display("\n--- Running %0d Randomized Tests ---", NUM_RANDOM_TESTS);
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            run_test($random, $random, $random, $sformatf("Random Test %0d", i + 1));
        end

        // --- Test Summary ---
        $display("\n=============================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("=============================================\n");

        $finish;
    end

endmodule
