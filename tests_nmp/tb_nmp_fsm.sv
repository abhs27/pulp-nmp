`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_fsm_hash
// Project       : PULPino NMP Extension
// Description   : Verifies the FSM control logic by mocking the datapath
//                 and surrounding modules.
//-----------------------------------------------------------------------------
module tb_nmp_fsm;

    // Parameters
    localparam CLK_PERIOD = 10;

    // FSM Interface
    reg         clk = 0;
    reg         rst_n;
    reg         nmp_valid_start;
    reg         use_hash_mode;
    reg  [4:0]  array_size;
    reg  [1:0]  addr_load_counter; // Mocked, not used in hash mode
    reg  [4:0]  element_counter;
    reg         rs1_read_done;
    reg         rs2_read_done;
    reg         write_done;
    reg         hash_addr_valid;
    reg         hash_addr_not_found;
    reg  [2:0]  funct3;
    reg         op_done;

    wire        nmp_active;
    wire        inter_flag;
    wire [3:0]  current_state;
    wire        start_op;
    wire        start_addr_load;
    wire        start_hash_lookup;
    wire        start_element_read;
    wire        start_element_write;
    wire        increment_element;
    wire        operation_complete;
    wire        hash_error;

    // Operation Codes
    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_MUL = 3'b010;
    localparam [2:0] OP_DIV = 3'b011;

    // FSM States (for monitoring)
    localparam [3:0] IDLE                = 4'b0000;
    localparam [3:0] LOAD_ADDRESSES      = 4'b0001;
    localparam [3:0] HASH_LOOKUP         = 4'b0010;
    localparam [3:0] EXECUTE_INIT        = 4'b0011;
    localparam [3:0] EXECUTE_READ        = 4'b0100;
    localparam [3:0] EXECUTE_COMPUTE_WAIT = 4'b0101;
    localparam [3:0] EXECUTE_WRITE       = 4'b0110;
    localparam [3:0] DONE                = 4'b0111;
    localparam [3:0] ERROR               = 4'b1000;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate DUT
    nmp_fsm_hash dut (.*);

    // Clock generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Mock datapath signals
    reg [5:0] hash_latency_ctr, read_latency_ctr, write_latency_ctr, op_latency_ctr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            element_counter <= 0;
        end else begin
            if (current_state == IDLE) begin
                element_counter <= 0;
            end else if (increment_element) begin
                element_counter <= element_counter + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hash_latency_ctr <= 0;
            read_latency_ctr <= 0;
            write_latency_ctr <= 0;
            op_latency_ctr <= 0;
            hash_addr_valid <= 0;
            rs1_read_done <= 0;
            rs2_read_done <= 0;
            op_done <= 0;
            write_done <= 0;
        end else begin
            // Default de-assertions
            hash_addr_valid <= 0;
            rs1_read_done <= 0;
            rs2_read_done <= 0;
            op_done <= 0;
            write_done <= 0;

            // Latency counters
            if (start_hash_lookup) hash_latency_ctr <= 2;
            else if (hash_latency_ctr > 0) hash_latency_ctr <= hash_latency_ctr - 1;

            if (start_element_read) read_latency_ctr <= 2;
            else if (read_latency_ctr > 0) read_latency_ctr <= read_latency_ctr - 1;

            if (start_op) begin
                case (funct3)
                    OP_ADD, OP_SUB: op_latency_ctr <= 1;
                    OP_MUL:         op_latency_ctr <= 4;
                    OP_DIV:         op_latency_ctr <= 35;
                    default:        op_latency_ctr <= 1;
                endcase
            end else if (op_latency_ctr > 0) begin
                op_latency_ctr <= op_latency_ctr - 1;
            end
            
            if (start_element_write) write_latency_ctr <= 2;
            else if (write_latency_ctr > 0) write_latency_ctr <= write_latency_ctr - 1;

            // Assert done signals
            if (hash_latency_ctr == 1 && !hash_addr_not_found) hash_addr_valid <= 1;
            if (read_latency_ctr == 1) {rs1_read_done, rs2_read_done} <= 2'b11;
            if (op_latency_ctr == 1) op_done <= 1;
            if (write_latency_ctr == 1) write_done <= 1;
        end
    end

    // Task to run a full FSM test
    task run_fsm_test;
        input [2:0] t_op;
        input [4:0] t_size;
        input string test_name;
        
        integer timeout;
        integer final_element_count;
        begin
            test_count++;
            // Reset sequence
            rst_n = 0;
            nmp_valid_start = 0;
            use_hash_mode = 1; // Always use hash mode for these tests
            array_size = t_size;
            funct3 = t_op;
            #(CLK_PERIOD * 5);
            rst_n = 1;
            @(posedge clk);
            
            // Start the FSM
            nmp_valid_start = 1;
            @(posedge clk);
            nmp_valid_start = 0;

            // Wait for completion
            timeout = 0;
            while(!operation_complete && timeout < 500) begin
                @(posedge clk);
                timeout++;
            end

            final_element_count = element_counter;

            if (timeout >= 500) begin
                $display("[FAIL] %s: Timeout waiting for operation_complete.", test_name);
                fail_count++;
            end else if (final_element_count !== t_size) begin
                $display("[FAIL] %s: Incorrect number of elements processed.", test_name);
                $display("       Expected: %0d, Got: %0d", t_size, final_element_count);
                fail_count++;
            end else begin
                $display("[PASS] %s (completed in %0d cycles)", test_name, timeout);
                pass_count++;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n======================================");
        $display("=== Testbench for nmp_fsm_hash ===");
        $display("======================================\n");

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");
        run_fsm_test(OP_ADD, 5'd4, "ADD operation, 4 elements");
        run_fsm_test(OP_SUB, 5'd2, "SUB operation, 2 elements");
        run_fsm_test(OP_MUL, 5'd3, "MUL operation, 3 elements");
        run_fsm_test(OP_DIV, 5'd1, "DIV operation, 1 element");
        run_fsm_test(OP_ADD, 5'd1, "Single element execution");
        run_fsm_test(OP_MUL, 5'd31, "Max elements execution");

        // Test error case
        test_count++;
        $display("\n--- Testing Hash Not Found Error ---");
        rst_n = 0; #(CLK_PERIOD * 5); rst_n = 1; @(posedge clk);
        nmp_valid_start = 1; @(posedge clk); nmp_valid_start = 0;
        // Mock environment modification for this specific test
        fork
            begin
                @(posedge dut.start_hash_lookup);
                @(posedge clk); @(posedge clk);
                hash_addr_not_found = 1;
                @(posedge clk);
                hash_addr_not_found = 0;
            end
        join
        wait(inter_flag);
        if (hash_error) begin
            $display("[PASS] Hash Not Found Error Test");
            pass_count++;
        end else begin
            $display("[FAIL] Hash Not Found Error Test: hash_error was not asserted.");
            fail_count++;
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
