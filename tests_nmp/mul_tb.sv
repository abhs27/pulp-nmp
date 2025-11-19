`timescale 1ns / 1ps

module tb_pipelined_fma;

    localparam CLK_PERIOD = 10;
    localparam NUM_TESTS  = 100;

    reg         clk;
    reg         rst;
    reg  signed [31:0] a;
    reg  signed [31:0] b;
    reg  signed [63:0] c;
    wire signed [63:0] result;

    // DUT
    multiplier dut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .c(c),
        .result(result)
    );

    // Clock
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Golden Model
    function automatic signed [63:0] golden_fma;
        input signed [31:0] op_a;
        input signed [31:0] op_b;
        input signed [63:0] op_c;
        begin
            golden_fma = op_a * op_b + op_c;
        end
    endfunction

    // Test vars
    integer test_num;
    reg signed [63:0] expected;
    reg all_passed = 1'b1;
    reg [31:0] rand_seed = 32'd12345;

    // Robust Test Task (4-cycle latency + 1 idle to flush)
    task run_test;
        input signed [31:0] test_a;
        input signed [31:0] test_b;
        input signed [63:0] test_c;
        begin
            // Apply inputs on posedge
            @(posedge clk);
            a = test_a;
            b = test_b;
            c = test_c;

            // Wait for the 4-stage pipeline latency
            repeat (4) @(posedge clk);

            // Check result
            expected = golden_fma(test_a, test_b, test_c);
            if (result == expected) begin
                $display("PASS: %0d * %0d + %0d = %0d", test_a, test_b, test_c, result);
            end else begin
                $display("FAIL: %0d * %0d + %0d = %0d (exp %0d)", test_a, test_b, test_c, result, expected);
                all_passed = 1'b0;
            end

            // Idle cycle: Feed zeros to flush any residue
            a = 32'sh0;
            b = 32'sh0;
            c = 64'sh0;
            @(posedge clk);
        end
    endtask

    // Main sequence
    initial begin
        // Init
        clk = 1'b0;
        rst = 1'b1;
        a = 32'sh0;
        b = 32'sh0;
        c = 64'sh0;

        // Reset sequence
        # (2 * CLK_PERIOD);
        rst = 1'b0;
        # CLK_PERIOD;

        $display("\n=== Pipelined FMA Verification (4-stage latency) ===\n");

        // Corner cases
        run_test(32'd0, 32'd0, 64'd0);
        run_test(32'd1, 32'd1, 64'd0);
        run_test(32'd100, 32'd200, 64'd500);
        run_test(-32'd100, -32'd200, 64'd500);
        run_test(32'h7FFFFFFF, 32'd2, 64'd0);
        run_test(32'h80000000, 32'd2, 64'd0);

        // Random tests
        $display("\n--- Running %0d random tests ---", NUM_TESTS);
        for (test_num = 0; test_num < NUM_TESTS; test_num = test_num + 1) begin
            a = $random(rand_seed) % (1 << 30);  // Avoid extreme values for stability
            b = $random(rand_seed) % (1 << 30);
            c = {$random(rand_seed), $random(rand_seed)};
            run_test(a, b, c);
        end

        // Summary
        if (all_passed) begin
            $display("\n*** ALL TESTS PASSED! ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED! ***\n");
        end

        # (5 * CLK_PERIOD);
        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("pipelined_fma.vcd");
        $dumpvars(1, tb_pipelined_fma);
    end

endmodule
