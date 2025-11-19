`timescale 1ns / 1ps

module tb_divider;

    localparam NUM_TESTS = 100;
    localparam CLK_PERIOD = 10;

    // Clock and Reset
    reg clk = 0;
    reg rst_n = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // DUT Interface
    reg  signed [31:0] a;
    reg  signed [31:0] b;
    reg         start;
    wire signed [31:0] q;
    wire        done;

    // DUT
    divider dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(a),
        .b(b),
        .q(q),
        .done(done)
    );

    // Golden Model
    function automatic signed [31:0] golden_divider;
        input signed [31:0] op_a;
        input signed [31:0] op_b;
        begin
            if (op_b == 0) begin
                golden_divider = 32'hFFFFFFFF; // Convention for division by zero
            end else begin
                // Verilog's division operator truncates towards zero.
                // The RTL implements non-restoring division which behaves differently for negative numbers.
                // We need to replicate the specific behavior of the RTL's algorithm.
                if (op_a < 0 && op_b > 0) begin
                    golden_divider = -(-op_a / op_b);
                end else if (op_a > 0 && op_b < 0) begin
                    golden_divider = -(op_a / -op_b);
                end else begin
                    golden_divider = op_a / op_b;
                end
            end
        end
    endfunction

    // Test vars
    integer test_num;
    reg signed [31:0] expected_q;
    reg all_passed = 1'b1;
    integer pass_count = 0;
    integer fail_count = 0;

    // Test Task
    task run_test;
        input signed [31:0] test_a;
        input signed [31:0] test_b;
        begin
            integer timeout_counter;

            // Apply inputs and start signal
            @(posedge clk);
            a = test_a;
            b = test_b;
            start = 1;
            $display("Starting test: %d / %d", test_a, test_b);
            @(posedge clk);
            start = 0;

            // Sequential wait for 'done' with a 100-cycle timeout, using a while loop
            timeout_counter = 0;
            while (dut.done !== 1'b1 && timeout_counter < 100) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
            end

            // Check for timeout or verify result
            if (timeout_counter >= 100) begin
                $display("FAIL: Timeout waiting for done signal for %d / %d", test_a, test_b);
                all_passed = 1'b0;
                fail_count = fail_count + 1;
            end else begin
                // Check result
                expected_q = golden_divider(test_a, test_b);
                if (q === expected_q) begin
                    $display("PASS: %d / %d = %d", test_a, test_b, q);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: %d / %d = %d (exp %d)", test_a, test_b, q, expected_q);
                    all_passed = 1'b0;
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    // Main sequence
    initial begin
        $display("\n=== Sequential Divider Verification ===\n");

        // Reset sequence
        start = 0;
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        @(posedge clk);

        // Corner cases
        $display("\n--- Running corner case tests ---");
        run_test(10, 3);
        run_test(-10, 3);
        run_test(10, -3);
        run_test(-10, -3);
        run_test(100, 10);
        run_test(0, 5);
        run_test(10, 1);
        run_test(32'hFFFFFFFF, 1); // -1 / 1
        run_test(32'h80000000, -1); // INT_MIN / -1
        run_test(32'hFFFFFFFF, 32'hFFFFFFFF); // -1 / -1
        
        // Division by zero (special case)
        $display("\n--- Testing division by zero ---");
        run_test(100, 0);
        run_test(0, 0);
        run_test(-100, 0);

        // Random tests
        $display("\n--- Running %0d random tests ---", NUM_TESTS);
        for (test_num = 0; test_num < NUM_TESTS; test_num = test_num + 1) begin
            logic signed [31:0] temp_a, temp_b;
            temp_a = $random;
            temp_b = $random;
            if (temp_b == 0) temp_b = $random;
            if (temp_b == 0) temp_b = 1;
            run_test(temp_a, temp_b);
        end

        // Summary
        $display("\n--- Test Summary ---");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (all_passed) begin
            $display("\n*** ALL TESTS PASSED! ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED! ***\n");
        end

        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("divider.vcd");
        $dumpvars(0, tb_divider);
    end

endmodule