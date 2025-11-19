`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_hash_addr_decoder
// Project       : PULPino NMP Extension
// Description   : Verifies the hash address decoder FSM and its interaction
//                 with a mocked Address Lookup Table (ALT).
//-----------------------------------------------------------------------------
module tb_nmp_hash_addr_decoder;

    // Parameters
    localparam CLK_PERIOD = 10;

    // DUT Interface
    reg         clk = 0;
    reg         rst_n;
    reg         lookup_enable;
    reg  [16:0] hash_index;
    wire [31:0] rs1_base_addr;
    wire [31:0] rs2_base_addr;
    wire [31:0] rd_base_addr;
    wire        addr_valid;
    wire        addr_not_found;

    // Interface to Mock ALT
    wire        alt_read_enable;
    wire [16:0] alt_read_hash_index;
    reg  [31:0] alt_read_rs1_base;
    reg  [31:0] alt_read_rs2_base;
    reg  [31:0] alt_read_rd_base;
    reg         alt_read_valid;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate DUT
    nmp_hash_addr_decoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_enable(lookup_enable),
        .hash_index(hash_index),
        .rs1_base_addr(rs1_base_addr),
        .rs2_base_addr(rs2_base_addr),
        .rd_base_addr(rd_base_addr),
        .addr_valid(addr_valid),
        .addr_not_found(addr_not_found),
        .alt_read_enable(alt_read_enable),
        .alt_read_hash_index(alt_read_hash_index),
        .alt_read_rs1_base(alt_read_rs1_base),
        .alt_read_rs2_base(alt_read_rs2_base),
        .alt_read_rd_base(alt_read_rd_base),
        .alt_read_valid(alt_read_valid)
    );

    // Clock generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------
    // Mock Address Lookup Table (ALT)
    //-------------------------------------
    localparam [16:0] VALID_HASH_1 = 17'h1A2B3;
    localparam [31:0] VH1_RS1 = 32'h1000_0000;
    localparam [31:0] VH1_RS2 = 32'h2000_0000;
    localparam [31:0] VH1_RD  = 32'h3000_0000;

    localparam [16:0] VALID_HASH_2 = 17'h0CDEF;
    localparam [31:0] VH2_RS1 = 32'h4444_0000;
    localparam [31:0] VH2_RS2 = 32'h5555_0000;
    localparam [31:0] VH2_RD  = 32'h6666_0000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alt_read_valid <= 1'b0;
            alt_read_rs1_base <= 32'h0;
            alt_read_rs2_base <= 32'h0;
            alt_read_rd_base  <= 32'h0;
        end else begin
            if (alt_read_enable) begin
                case (alt_read_hash_index)
                    VALID_HASH_1: begin
                        alt_read_rs1_base <= VH1_RS1;
                        alt_read_rs2_base <= VH1_RS2;
                        alt_read_rd_base  <= VH1_RD;
                        alt_read_valid    <= 1'b1;
                    end
                    VALID_HASH_2: begin
                        alt_read_rs1_base <= VH2_RS1;
                        alt_read_rs2_base <= VH2_RS2;
                        alt_read_rd_base  <= VH2_RD;
                        alt_read_valid    <= 1'b1;
                    end
                    default: begin
                        alt_read_rs1_base <= 32'h0;
                        alt_read_rs2_base <= 32'h0;
                        alt_read_rd_base  <= 32'h0;
                        alt_read_valid    <= 1'b0; // Hash not in our mock table
                    end
                endcase
            end else begin
                alt_read_valid <= 1'b0;
            end
        end
    end

    // Task to run a lookup and check the result
    task run_lookup_test;
        input [16:0] t_hash;
        input        expect_valid; // 1 if we expect addr_valid, 0 if we expect addr_not_found
        input string test_name;
        
        integer timeout;
        begin
            test_count++;
            @(posedge clk);
            hash_index = t_hash;
            lookup_enable = 1'b1;
            @(posedge clk);
            lookup_enable = 1'b0;

            // Wait for addr_valid or addr_not_found, with a timeout
            timeout = 0;
            while (!addr_valid && !addr_not_found && timeout < 10) begin
                @(posedge clk);
                timeout++;
            end

            if (timeout >= 10) begin
                $display("[FAIL] %s: Timeout waiting for response.", test_name);
                fail_count++;
            end else if (expect_valid) begin
                if (addr_valid) begin
                    if (rs1_base_addr === VH1_RS1 && rs2_base_addr === VH1_RS2 && rd_base_addr === VH1_RD) begin
                         $display("[PASS] %s", test_name);
                         pass_count++;
                    end else begin
                         $display("[FAIL] %s: addr_valid is high, but address data is incorrect.", test_name);
                         fail_count++;
                    end
                end else begin
                    $display("[FAIL] %s: Expected addr_valid, but got addr_not_found.", test_name);
                    fail_count++;
                end
            end else begin // expect_not_found
                if (addr_not_found) begin
                    $display("[PASS] %s", test_name);
                    pass_count++;
                end else begin
                    $display("[FAIL] %s: Expected addr_not_found, but got addr_valid.", test_name);
                    fail_count++;
                end
            end
            @(posedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        $display("\n=============================================");
        $display("=== Testbench for nmp_hash_addr_decoder ===");
        $display("=============================================\n");

        // Reset
        rst_n = 1'b0;
        lookup_enable = 1'b0;
        hash_index = 17'h0;
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        @(posedge clk);

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");

        // Test 1: Find a valid hash
        run_lookup_test(VALID_HASH_1, 1'b1, "Find Valid Hash");

        // Test 2: Hash not found
        run_lookup_test(17'h7FFFF, 1'b0, "Hash Not Found");

        // Test 3: Back-to-back lookups
        run_lookup_test(VALID_HASH_1, 1'b1, "Back-to-back 1 (Valid)");
        run_lookup_test(17'h7FFFF, 1'b0, "Back-to-back 2 (Invalid)");
        
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
