`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Comprehensive NMP Top-Level Testbench
// Project       : PULPino NMP Extension
// Description   : A full end-to-end verification environment for the nmp_top_hash
//                 module. It includes a memory model, a triple-port AXI slave,
//                 and a suite of directed and randomized tests for all ops.
//-----------------------------------------------------------------------------
module tb_nmp_comprehensive;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam MEM_SIZE = 8192; // 32KB memory
    localparam TIMEOUT_CYCLES = 4000;
    localparam NUM_RANDOM_TESTS = 50;

    // Testbench Signals
    reg clk = 0;
    reg rst_n;
    reg [31:0] instruction;
    reg instruction_valid;
    reg alt_write_enable;
    reg [16:0] alt_write_hash_index;
    reg [31:0] alt_write_rs1_base, alt_write_rs2_base, alt_write_rd_base;

    // DUT Wires
    wire nmp_active, inter_flag, hash_error;
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire axia_arvalid, axib_arvalid, axic_awvalid;
    wire axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire axic_wvalid;

    // AXI Slave Signals
    reg axia_arready, axib_arready, axic_awready, axic_wready;
    reg [31:0] axia_rdata, axib_rdata;
    reg axia_rvalid, axib_rvalid, axic_bvalid;

    // Mock Memory
    reg [31:0] memory [0:MEM_SIZE-1];

    // Test Tracking
    integer test_count = 0, pass_count = 0, fail_count = 0;

    // Operation Codes
    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_MUL = 3'b010;
    localparam [2:0] OP_DIV = 3'b011;

    // DUT Instantiation
    nmp_top_hash #(.HASH_MODE_ENABLE(1'b1)) dut (.*);

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------
    // Triple-Port AXI Slave & Memory Model
    //-------------------------------------
    // This slave can handle one request per port per cycle
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 0; axib_rvalid <= 0; axic_bvalid <= 0;
        end else begin
            // Port A (RS1 Reads)
            if (axia_arvalid && axia_arready) begin
                axia_rdata <= memory[axia_araddr >> 2];
                axia_rvalid <= 1'b1;
            end else if (axia_rready) begin
                axia_rvalid <= 1'b0;
            end
            // Port B (RS2 Reads)
            if (axib_arvalid && axib_arready) begin
                axib_rdata <= memory[axib_araddr >> 2];
                axib_rvalid <= 1'b1;
            end else if (axib_rready) begin
                axib_rvalid <= 1'b0;
            end
            // Port C (RD Writes)
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
                memory[axic_awaddr >> 2] <= axic_wdata;
                axic_bvalid <= 1'b1;
            end else if (axic_bready) begin
                axic_bvalid <= 1'b0;
            end
        end
    end

    //-------------------------------------
    // Helper Functions and Tasks
    //-------------------------------------
    function [31:0] create_instruction(input [16:0] hash, input [2:0] f3, input [4:0] size);
        return {hash, f3, size, 7'h6B};
    endfunction

    function automatic signed [31:0] golden_op(input signed [31:0] a, input signed [31:0] b, input [2:0] op);
        case(op)
            OP_ADD: return a + b;
            OP_SUB: return a - b;
            OP_MUL: return a * b;
            OP_DIV: return (b == 0) ? 32'hFFFFFFFF : a / b;
            default: return 32'hDEADBEEF;
        endcase
    endfunction

    task run_nmp_test;
        input string test_name;
        input [2:0] op_code;
        input [4:0] size;
        input signed [31:0] rs1_data_pattern [0:31];
        input signed [31:0] rs2_data_pattern [0:31];

        integer i, errors;
        reg [31:0] rs1_base, rs2_base, rd_base;
        reg [16:0] hash;
        reg [31:0] instr;
        integer timeout;
        begin
            test_count++;
            $display("\n--- Running Test: %s (op: %0d, size: %0d) ---", test_name, op_code, size);
            
            // 1. Setup Phase
            rs1_base = 32'h1000;
            rs2_base = 32'h2000;
            rd_base  = 32'h3000;
            hash     = 17'h12345; // Use a fixed hash for simplicity

            for (i = 0; i < MEM_SIZE; i++) memory[i] = 32'h0;
            for (i = 0; i < size; i++) begin
                memory[rs1_base[12:2] + i] = rs1_data_pattern[i];
                memory[rs2_base[12:2] + i] = rs2_data_pattern[i];
            end

            @(posedge clk);
            alt_write_enable = 1;
            alt_write_hash_index = hash;
            alt_write_rs1_base = rs1_base;
            alt_write_rs2_base = rs2_base;
            alt_write_rd_base = rd_base;
            @(posedge clk);
            alt_write_enable = 0;

            // 2. Execution Phase
            instr = create_instruction(hash, op_code, size);
            @(posedge clk);
            instruction = instr;
            instruction_valid = 1;
            @(posedge clk);
            instruction_valid = 0;

            timeout = 0;
            while(!inter_flag && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout++;
            end

            // 3. Verification Phase
            if (timeout >= TIMEOUT_CYCLES) begin
                $display("[FAIL] Test timed out.");
                fail_count++;
            end else if (hash_error) begin
                $display("[FAIL] Hash error was asserted unexpectedly.");
                fail_count++;
            end else begin
                errors = 0;
                for (i = 0; i < size; i++) begin
                    reg signed [31:0] expected = golden_op(rs1_data_pattern[i], rs2_data_pattern[i], op_code);
                    reg signed [31:0] actual = memory[rd_base[12:2] + i];
                    if (actual !== expected) begin
                        $display("  Mismatch at index %0d: Expected %d, Got %d", i, expected, actual);
                        errors++;
                    end
                end

                if (errors == 0) begin
                    $display("[PASS] All %0d elements correct. (Cyles: %0d)", size, timeout);
                    pass_count++;
                end else begin
                    $display("[FAIL] Found %0d errors in result array.", errors);
                    fail_count++;
                end
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n==================================================");
        $display("=== Comprehensive NMP Top-Level Verification ===");
        $display("==================================================\n");

        // Reset
        rst_n = 0; instruction_valid = 0; alt_write_enable = 0;
        axia_arready = 1; axib_arready = 1; axic_awready = 1; axic_wready = 1;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        @(posedge clk);

        // --- Directed Tests ---
        reg signed [31:0] d_rs1 [0:31], d_rs2 [0:31];
        d_rs1 = '{10, -20, 30, 0};
        d_rs2 = '{5, 10, -15, 100};
        run_nmp_test("Directed ADD", OP_ADD, 4, d_rs1, d_rs2);
        run_nmp_test("Directed SUB", OP_SUB, 4, d_rs1, d_rs2);
        run_nmp_test("Directed MUL", OP_MUL, 4, d_rs1, d_rs2);
        run_nmp_test("Directed DIV", OP_DIV, 4, d_rs1, d_rs2);
        
        // DIV by zero corner case
        d_rs1[0] = 100;
        d_rs2[0] = 0;
        run_nmp_test("DIV by Zero", OP_DIV, 1, d_rs1, d_rs2);

        // --- Randomized Tests ---
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            reg [4:0] rand_size;
            reg [1:0] rand_op_idx;
            reg [2:0] rand_op;
            reg signed [31:0] r_rs1 [0:31], r_rs2 [0:31];

            rand_size = $urandom_range(1, 31);
            rand_op_idx = $urandom_range(0, 3);
            case(rand_op_idx)
                0: rand_op = OP_ADD;
                1: rand_op = OP_SUB;
                2: rand_op = OP_MUL;
                3: rand_op = OP_DIV;
            endcase

            for (int j = 0; j < rand_size; j++) begin
                r_rs1[j] = $random;
                r_rs2[j] = $random;
                if (rand_op == OP_DIV && r_rs2[j] == 0) r_rs2[j] = 1; // Avoid div by zero
            end
            
            run_nmp_test($sformatf("Random Test %0d", i+1), rand_op, rand_size, r_rs1, r_rs2);
        end

        // --- Test Summary ---
        $display("\n==================================================");
        $display("--- Final Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("==================================================\n");

        $finish;
    end

endmodule
