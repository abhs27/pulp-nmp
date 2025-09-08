// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// NMP Top Module Comprehensive Testbench                                   //
// Tests all 5 NMP operations with various test vectors                     //
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_nmp_top;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Core interface signals
  logic        nmp_req;
  logic        nmp_gnt;
  logic [31:0] nmp_addr;
  logic [31:0] nmp_wdata;
  logic [31:0] nmp_rdata;
  logic        nmp_we;
  logic [3:0]  nmp_be;
  logic [2:0]  nmp_op;
  logic [6:0]  nmp_funct7;
  logic        nmp_valid;
  logic        nmp_ready;
  logic [31:0] nmp_result;
  logic        nmp_error;
  logic [7:0]  nmp_status;
  logic        nmp_busy;
  
  // Memory interface signals  
  logic        mem_req;
  logic        mem_gnt;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;
  logic        mem_we;
  logic [3:0]  mem_be;
  logic        mem_valid;
  logic        mem_error;
  
  // Configuration signals
  logic        nmp_enable;
  logic        nmp_reset;
  logic [31:0] nmp_perf_counter;
  logic [7:0]  nmp_unit_status;
  logic        nmp_interrupt;
  
  // Test memory (4KB)
  logic [7:0] test_memory[0:4095];
  
  // Test status variables
  int test_pass_count;
  int test_fail_count;
  string current_test;
  
  // NMP operation codes
  localparam NMP_SEARCH = 3'b000;
  localparam NMP_SORT   = 3'b001;
  localparam NMP_REDUCE = 3'b010;
  localparam NMP_FILTER = 3'b011;
  localparam NMP_MAP    = 3'b100;
  
  // Reduce operation types
  localparam REDUCE_SUM     = 3'b000;
  localparam REDUCE_PRODUCT = 3'b001;
  localparam REDUCE_MIN     = 3'b010;
  localparam REDUCE_MAX     = 3'b011;
  localparam REDUCE_AND     = 3'b100;
  localparam REDUCE_OR      = 3'b101;
  localparam REDUCE_XOR     = 3'b110;
  
  // Map operation types
  localparam MAP_SCALE  = 3'b000;
  localparam MAP_ADD    = 3'b001;
  localparam MAP_SQUARE = 3'b010;
  localparam MAP_ABS    = 3'b011;
  localparam MAP_NEGATE = 3'b100;
  localparam MAP_SHIFT  = 3'b101;
  
  // DUT Instance
  nmp_top dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    // Core interface
    .nmp_req_i(nmp_req),
    .nmp_gnt_o(nmp_gnt),
    .nmp_addr_i(nmp_addr),
    .nmp_wdata_i(nmp_wdata),
    .nmp_rdata_o(nmp_rdata),
    .nmp_we_i(nmp_we),
    .nmp_be_i(nmp_be),
    .nmp_op_i(nmp_op),
    .nmp_funct7_i(nmp_funct7),
    .nmp_valid_o(nmp_valid),
    .nmp_ready_o(nmp_ready),
    .nmp_result_o(nmp_result),
    .nmp_error_o(nmp_error),
    .nmp_status_o(nmp_status),
    .nmp_busy_o(nmp_busy),
    // Memory interface
    .mem_req_o(mem_req),
    .mem_gnt_i(mem_gnt),
    .mem_addr_o(mem_addr),
    .mem_wdata_o(mem_wdata),
    .mem_rdata_i(mem_rdata),
    .mem_we_o(mem_we),
    .mem_be_o(mem_be),
    .mem_valid_i(mem_valid),
    .mem_error_i(mem_error),
    // Configuration
    .nmp_enable_i(nmp_enable),
    .nmp_reset_i(nmp_reset),
    .nmp_perf_counter_o(nmp_perf_counter),
    .nmp_unit_status_o(nmp_unit_status),
    .nmp_interrupt_o(nmp_interrupt)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end
  
  // Memory model - simple behavioral memory
  always_ff @(posedge clk) begin
    if (mem_req && mem_gnt) begin
      if (mem_we) begin
        // Write operation
        for (int i = 0; i < 4; i++) begin
          if (mem_be[i]) begin
            test_memory[mem_addr[11:0] + i] <= mem_wdata[i*8 +: 8];
          end
        end
      end
      mem_valid <= 1'b1;
      if (!mem_we) begin
        // Read operation
        mem_rdata <= {test_memory[mem_addr[11:0] + 3],
                      test_memory[mem_addr[11:0] + 2],
                      test_memory[mem_addr[11:0] + 1],
                      test_memory[mem_addr[11:0]]};
      end
    end else begin
      mem_valid <= 1'b0;
    end
  end
  
  // Grant memory access immediately
  assign mem_gnt = mem_req;
  assign mem_error = 1'b0;
  
  // Test tasks
  task reset_system();
    begin
      rst_n = 0;
      nmp_req = 0;
      nmp_addr = 0;
      nmp_wdata = 0;
      nmp_we = 0;
      nmp_be = 4'hF;
      nmp_op = 0;
      nmp_funct7 = 0;
      nmp_enable = 1;
      nmp_reset = 0;
      repeat(5) @(posedge clk);
      rst_n = 1;
      repeat(5) @(posedge clk);
    end
  endtask
  
  task init_memory();
    begin
      // Initialize test memory with pattern data
      for (int i = 0; i < 4096; i++) begin
        test_memory[i] = i & 8'hFF;
      end
      // Add specific test patterns
      // Pattern for search test
      test_memory[100] = 8'hAA;
      test_memory[200] = 8'hAA;
      test_memory[300] = 8'hBB;
      // Pattern for sort test (16 bytes)
      for (int i = 0; i < 16; i++) begin
        test_memory[512 + i] = 16 - i; // Reverse order
      end
      // Pattern for reduce test (32 bytes)
      for (int i = 0; i < 32; i++) begin
        test_memory[768 + i] = i + 1;
      end
    end
  endtask
  
  task nmp_operation(
    input logic [2:0] op_type,
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [6:0] funct7
  );
    begin
      @(posedge clk);
      nmp_req <= 1'b1;
      nmp_op <= op_type;
      nmp_addr <= addr;
      nmp_wdata <= data;
      nmp_funct7 <= funct7;
      nmp_we <= 1'b0;
      
      // Wait for grant
      wait(nmp_gnt);
      @(posedge clk);
      nmp_req <= 1'b0;
      
      // Wait for completion
      wait(nmp_valid);
      @(posedge clk);
    end
  endtask
  
  task check_result(
    input logic [31:0] expected,
    input string test_name
  );
    begin
      if (nmp_result == expected && !nmp_error) begin
        $display("[PASS] %s: Result = 0x%08x", test_name, nmp_result);
        test_pass_count++;
      end else begin
        $display("[FAIL] %s: Expected = 0x%08x, Got = 0x%08x, Error = %b", 
                 test_name, expected, nmp_result, nmp_error);
        test_fail_count++;
      end
    end
  endtask
  
  // Test 1: Search Operation
  task test_search();
    begin
      $display("\n=== Test 1: Search Operation ===");
      current_test = "SEARCH";
      
      // Search for value 0xAA starting at address 0
      // funct7[6:5] = 00 (8-bit), funct7[4:2] = 000, funct7[1:0] = 00
      nmp_operation(NMP_SEARCH, 32'h00000000, 32'h000000AA, 7'b0000000);
      check_result(32'h00000064, "Search 0xAA from addr 0 (found at 100)");
      
      // Search for value 0xBB starting at address 0
      nmp_operation(NMP_SEARCH, 32'h00000000, 32'h000000BB, 7'b0000000);
      check_result(32'h0000012C, "Search 0xBB from addr 0 (found at 300)");
      
      // Search for non-existent value
      nmp_operation(NMP_SEARCH, 32'h00000000, 32'h000000FF, 7'b0000000);
      if (nmp_error) begin
        $display("[PASS] Search for non-existent value returned error");
        test_pass_count++;
      end else begin
        $display("[FAIL] Search for non-existent value should return error");
        test_fail_count++;
      end
    end
  endtask
  
  // Test 2: Sort Operation  
  task test_sort();
    begin
      $display("\n=== Test 2: Sort Operation ===");
      current_test = "SORT";
      
      // Sort 16 bytes at address 512, ascending order
      // funct7[6] = 0 (ascending), funct7[5:0] = 16 (count)
      nmp_operation(NMP_SORT, 32'h00000200, 32'h00000000, 7'b0010000);
      
      // Wait extra cycles for sort to complete
      repeat(100) @(posedge clk);
      
      // Check if sorted correctly
      logic sorted_correctly = 1'b1;
      for (int i = 0; i < 15; i++) begin
        if (test_memory[512 + i] > test_memory[512 + i + 1]) begin
          sorted_correctly = 1'b0;
        end
      end
      
      if (sorted_correctly && !nmp_error) begin
        $display("[PASS] Sort ascending 16 elements");
        test_pass_count++;
      end else begin
        $display("[FAIL] Sort ascending failed, Error = %b", nmp_error);
        test_fail_count++;
      end
    end
  endtask
  
  // Test 3: Reduce Operation
  task test_reduce();
    begin
      $display("\n=== Test 3: Reduce Operation ===");
      current_test = "REDUCE";
      
      // Sum 32 bytes starting at address 768
      // funct7[6:4] = 000 (SUM), funct7[3:0] = unused
      nmp_operation(NMP_REDUCE, 32'h00000300, 32'h00000020, 7'b0000000);
      
      // Expected sum: 1+2+3+...+32 = 528
      check_result(32'h00000210, "Reduce SUM of 32 elements");
      
      // Max of 32 bytes
      // funct7[6:4] = 011 (MAX)
      nmp_operation(NMP_REDUCE, 32'h00000300, 32'h00000020, 7'b0110000);
      check_result(32'h00000020, "Reduce MAX of 32 elements");
      
      // Min of 32 bytes  
      // funct7[6:4] = 010 (MIN)
      nmp_operation(NMP_REDUCE, 32'h00000300, 32'h00000020, 7'b0100000);
      check_result(32'h00000001, "Reduce MIN of 32 elements");
    end
  endtask
  
  // Test 4: Filter Operation
  task test_filter();
    begin
      $display("\n=== Test 4: Filter Operation ===");
      current_test = "FILTER";
      
      // Filter values > 16 from first 32 bytes
      // funct7[6:4] = 001 (greater than), funct7[3:0] = threshold high nibble
      nmp_operation(NMP_FILTER, 32'h00000000, 32'h00000010, 7'b0010001);
      
      // Check filter results
      if (!nmp_error) begin
        $display("[PASS] Filter operation completed");
        test_pass_count++;
      end else begin
        $display("[FAIL] Filter operation failed");
        test_fail_count++;
      end
    end
  endtask
  
  // Test 5: Map Operation
  task test_map();
    begin
      $display("\n=== Test 5: Map Operation ===");
      current_test = "MAP";
      
      // Scale by 2 (multiply) first 16 bytes
      // funct7[6:4] = 000 (SCALE), funct7[3:0] = scale factor
      nmp_operation(NMP_MAP, 32'h00000000, 32'h00000010, 7'b0000010);
      
      // Verify scaling
      logic map_correct = 1'b1;
      for (int i = 0; i < 16; i++) begin
        if (test_memory[i] != ((i & 8'hFF) * 2) & 8'hFF) begin
          map_correct = 1'b0;
        end
      end
      
      if (map_correct && !nmp_error) begin
        $display("[PASS] Map SCALE operation");
        test_pass_count++;
      end else begin
        $display("[FAIL] Map SCALE operation");
        test_fail_count++;
      end
      
      // Test ADD operation
      // funct7[6:4] = 001 (ADD)
      nmp_operation(NMP_MAP, 32'h00000010, 32'h00000010, 7'b0010101);
      
      if (!nmp_error) begin
        $display("[PASS] Map ADD operation completed");
        test_pass_count++;
      end else begin
        $display("[FAIL] Map ADD operation failed");
        test_fail_count++;
      end
    end
  endtask
  
  // Main test sequence
  initial begin
    $display("\n========================================");
    $display("NMP Top Module Comprehensive Testbench");
    $display("========================================\n");
    
    test_pass_count = 0;
    test_fail_count = 0;
    
    // Initialize
    init_memory();
    reset_system();
    
    // Run all tests
    test_search();
    test_sort();
    test_reduce();
    test_filter();
    test_map();
    
    // Display final results
    $display("\n========================================");
    $display("Test Results Summary:");
    $display("PASSED: %0d tests", test_pass_count);
    $display("FAILED: %0d tests", test_fail_count);
    if (test_fail_count == 0) begin
      $display("ALL TESTS PASSED!");
    end else begin
      $display("SOME TESTS FAILED!");
    end
    $display("========================================\n");
    
    #100;
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #100000;
    $display("[ERROR] Test timeout!");
    $finish;
  end
  
  // Waveform dumping
  initial begin
    $dumpfile("tb_nmp_top.vcd");
    $dumpvars(0, tb_nmp_top);
  end

endmodule
