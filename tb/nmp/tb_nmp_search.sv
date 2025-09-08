// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// NMP Search Unit Testbench                                               //
// Basic testbench for the NMP search unit functionality                   //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module tb_nmp_search;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Test control
  logic test_passed;
  logic test_failed;
  integer test_count;
  
  // Memory model
  logic [31:0] test_memory [0:1023];
  
  // Interface instances
  nmp_if core_if();
  nmp_mem_if mem_if();
  nmp_config_if config_if();
  
  // DUT instantiation
  nmp_search_unit dut (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .core_if    (core_if.nmp_unit),
    .mem_if     (mem_if.nmp_unit),
    .config_if  (config_if.nmp_unit)
  );
  
  //////////////////////////////////////////////////////////////////////////////
  // Clock Generation
  //////////////////////////////////////////////////////////////////////////////
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Memory Model
  //////////////////////////////////////////////////////////////////////////////
  
  // Simple memory model
  always_ff @(posedge clk) begin
    if (mem_if.req && mem_if.gnt) begin
      if (mem_if.we) begin
        test_memory[mem_if.addr[11:2]] <= mem_if.wdata;
      end
    end
  end
  
  always_comb begin
    mem_if.gnt = mem_if.req;
    mem_if.valid = mem_if.req;
    mem_if.rdata = test_memory[mem_if.addr[11:2]];
    mem_if.error = 1'b0;
    mem_if.resp = 2'b00;
    mem_if.burst_last = 1'b1;
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Core Interface Connections
  //////////////////////////////////////////////////////////////////////////////
  
  // Configuration interface
  assign config_if.enable = 1'b1;
  assign config_if.reset = 1'b0;
  assign config_if.clk_gate_en = 1'b1;
  assign config_if.config_data = 32'h0;
  assign config_if.config_addr = 8'h0;
  assign config_if.config_we = 1'b0;
  assign config_if.config_re = 1'b0;
  
  //////////////////////////////////////////////////////////////////////////////
  // Test Tasks
  //////////////////////////////////////////////////////////////////////////////
  
  task automatic reset_dut();
    rst_n = 1'b0;
    core_if.req = 1'b0;
    core_if.addr = 32'h0;
    core_if.wdata = 32'h0;
    core_if.we = 1'b0;
    core_if.be = 4'h0;
    core_if.nmp_op = 3'b000;
    core_if.nmp_funct7 = 7'b0000000;
    
    repeat(10) @(posedge clk);
    rst_n = 1'b1;
    repeat(5) @(posedge clk);
  endtask
  
  task automatic init_test_memory();
    // Initialize test memory with known pattern
    for (int i = 0; i < 1024; i++) begin
      test_memory[i] = i * 2; // Even numbers
    end
    // Add some target values
    test_memory[100] = 32'hDEADBEEF;
    test_memory[200] = 32'hCAFEBABE;
    test_memory[500] = 32'h12345678;
  endtask
  
  task automatic search_test(
    input logic [31:0] base_addr,
    input logic [31:0] search_value,
    input logic [6:0]  funct7,
    input logic [31:0] expected_result,
    input string       test_name
  );
    $display("Running test: %s", test_name);
    
    // Start search operation
    core_if.req = 1'b1;
    core_if.addr = base_addr;
    core_if.wdata = search_value;
    core_if.we = 1'b0;
    core_if.be = 4'hF;
    core_if.nmp_op = NMP_SEARCH;
    core_if.nmp_funct7 = funct7;
    
    @(posedge clk);
    wait(core_if.gnt);
    core_if.req = 1'b0;
    
    // Wait for completion
    wait(core_if.valid);
    
    if (core_if.error) begin
      $display("ERROR: %s - Operation failed with error", test_name);
      test_failed = 1'b1;
    end else if (core_if.result == expected_result) begin
      $display("PASS: %s - Found at index %d", test_name, core_if.result);
      test_passed = 1'b1;
    end else begin
      $display("FAIL: %s - Expected index %d, got %d", test_name, expected_result, core_if.result);
      test_failed = 1'b1;
    end
    
    test_count++;
    @(posedge clk);
  endtask
  
  //////////////////////////////////////////////////////////////////////////////
  // Main Test Sequence
  //////////////////////////////////////////////////////////////////////////////
  
  initial begin
    test_passed = 1'b0;
    test_failed = 1'b0;
    test_count = 0;
    
    $display("=== NMP Search Unit Testbench ===");
    
    // Initialize
    reset_dut();
    init_test_memory();
    
    // Test 1: Search for existing value
    search_test(
      .base_addr(32'h0000_0000),
      .search_value(32'hDEADBEEF),
      .funct7(7'b0001000), // 32-bit exact match
      .expected_result(32'd100),
      .test_name("Search existing value")
    );
    
    // Test 2: Search for another existing value
    search_test(
      .base_addr(32'h0000_0000),
      .search_value(32'hCAFEBABE),
      .funct7(7'b0001000), // 32-bit exact match
      .expected_result(32'd200),
      .test_name("Search another existing value")
    );
    
    // Test 3: Search for non-existing value
    search_test(
      .base_addr(32'h0000_0000),
      .search_value(32'h87654321),
      .funct7(7'b0001000), // 32-bit exact match
      .expected_result(32'hFFFFFFFF), // -1 (not found)
      .test_name("Search non-existing value")
    );
    
    // Test 4: Search with different base address
    search_test(
      .base_addr(32'h0000_0320), // Start from word 200
      .search_value(32'h12345678),
      .funct7(7'b0001000), // 32-bit exact match
      .expected_result(32'd300), // Relative index from start
      .test_name("Search with offset base")
    );
    
    // Wait for final operations to complete
    repeat(100) @(posedge clk);
    
    // Results
    $display("=== Test Results ===");
    $display("Total tests run: %d", test_count);
    
    if (test_failed) begin
      $display("SOME TESTS FAILED!");
      $finish(1);
    end else begin
      $display("ALL TESTS PASSED!");
      $finish(0);
    end
  end
  
  // Timeout
  initial begin
    #100000;
    $display("ERROR: Testbench timeout!");
    $finish(1);
  end

endmodule
