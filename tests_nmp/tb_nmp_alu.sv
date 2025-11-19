`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_alu (Multi-Cycle)
// Project       : PULPino NMP Extension
// Description   : Verifies all arithmetic operations (ADD, SUB, MUL, DIV)
//                 and their variable-latency completion signal.
//-----------------------------------------------------------------------------
module tb_nmp_alu;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam NUM_RANDOM_TESTS = 100;
    localparam TIMEOUT_CYCLES = 100;

    // DUT Interface
    reg         clk = 0;
    reg         rst_n;
    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    reg  [2:0]  operation;
    reg         start_op;
    wire [31:0] result;
    wire        overflow;
    wire        zero;
    wire        op_done;

    // Operation Codes
    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_MUL = 3'b010;
    localparam [2:0] OP_DIV = 3'b011;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate DUT
    nmp_alu dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operation(operation),
        .clk(clk),
        .rst_n(rst_n),
        .start_op(start_op),
        .result(result),
        .overflow(overflow),
        .zero(zero),
        .op_done(op_done)
    );

    // Clock generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Golden model for division (matches RTL's signed non-restoring behavior)
    function automatic signed [31:0] golden_divider;
        input signed [31:0] a, b;
        if (b == 0) return 32'hFFFFFFFF;
        else return a / b;
    endfunction

    // Task to run a single operation test
    task run_op_test;
        input [31:0] t_op_a, t_op_b;
        input [2:0]  t_op_code;
        input string test_name;
        
        reg signed [31:0] expected_result;
        integer timeout_counter;
        begin
            test_count++;
            @(posedge clk);
            operand_a = t_op_a;
            operand_b = t_op_b;
            operation = t_op_code;
            start_op = 1'b1;
            @(posedge clk);
            start_op = 1'b0;

            // Wait for op_done with a timeout
            timeout_counter = 0;
            while (!op_done && timeout_counter < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout_counter++;
            end

            if (timeout_counter >= TIMEOUT_CYCLES) begin
                $display("[FAIL] %s: Timeout waiting for op_done.", test_name);
                fail_count++;
            end else begin

                // Calculate expected result
                case (t_op_code)
                    OP_ADD: expected_result = t_op_a + t_op_b;
                    OP_SUB: expected_result = t_op_a - t_op_b;
                    OP_MUL: expected_result = t_op_a * t_op_b;
                    OP_DIV: expected_result = golden_divider(t_op_a, t_op_b);
                    default: expected_result = 32'hDEADBEEF;
                endcase

                // Check result
                if (result === expected_result) begin
                    $display("[PASS] %s (latency: %0d cycles)", test_name, timeout_counter);
                    pass_count++;
                end else begin
                    $display("[FAIL] %s (latency: %0d cycles)", test_name, timeout_counter);
                    $display("       Operands: %d, %d", $signed(t_op_a), $signed(t_op_b));
                    $display("       Expected: %d (%h), Got: %d (%h)", $signed(expected_result), expected_result, $signed(result), result);
                    fail_count++;
                end
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n======================================");
        $display("=== Testbench for nmp_alu ===");
        $display("======================================\n");

        // Reset
        rst_n = 1'b0;
        start_op = 1'b0;
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        @(posedge clk);

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");
        // ADD
        run_op_test(10, 20, OP_ADD, "ADD: 10 + 20");
        run_op_test(-10, 20, OP_ADD, "ADD: -10 + 20");
        run_op_test(32'h7FFFFFFF, 1, OP_ADD, "ADD: MAX_INT + 1 (overflow)");
        // SUB
        run_op_test(50, 20, OP_SUB, "SUB: 50 - 20");
        run_op_test(20, 50, OP_SUB, "SUB: 20 - 50");
        run_op_test(32'h80000000, 1, OP_SUB, "SUB: MIN_INT - 1 (overflow)");
        // MUL
        run_op_test(7, 8, OP_MUL, "MUL: 7 * 8");
        run_op_test(-7, 8, OP_MUL, "MUL: -7 * 8");
        run_op_test(-7, -8, OP_MUL, "MUL: -7 * -8");
        run_op_test(0, 123, OP_MUL, "MUL: 0 * 123");
        run_op_test(65536, 65536, OP_MUL, "MUL: Large numbers (truncation)");
        // DIV
        run_op_test(100, 10, OP_DIV, "DIV: 100 / 10");
        run_op_test(10, 3, OP_DIV, "DIV: 10 / 3 (truncation)");
        run_op_test(-10, 3, OP_DIV, "DIV: -10 / 3");
        run_op_test(10, -3, OP_DIV, "DIV: 10 / -3");
        run_op_test(-10, -3, OP_DIV, "DIV: -10 / -3");
        run_op_test(123, 0, OP_DIV, "DIV: Division by zero");
        run_op_test(32'h80000000, -1, OP_DIV, "DIV: MIN_INT / -1");

        // --- Randomized Tests ---
        $display("\n--- Running %0d Randomized Tests ---", NUM_RANDOM_TESTS);
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            reg [31:0] r_a, r_b;
            reg [1:0]  r_op;
            r_a = $random;
            r_b = $random;
            r_op = $random;

            // Avoid division by zero in random tests for simplicity
            if (r_op == OP_DIV[1:0] && r_b == 0) begin
                r_b = $random;
                if (r_b == 0) r_b = 1;
            end
            
            run_op_test(r_a, r_b, {1'b0, r_op}, $sformatf("Random Test %0d", i + 1));
        end

        // --- Test Summary ---
        $display("\n======================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("======================================\n");

        $finish;
    end

endmodule
