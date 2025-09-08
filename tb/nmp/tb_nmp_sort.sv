// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// NMP Sort Unit Testbench                                                  //
// Tests the sorting functionality with various array sizes and orders      //
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_nmp_sort;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Core interface
  nmp_if core_if();
  
  // Memory interface  
  nmp_mem_if mem_if();
  
  // Configuration interface
  nmp_config_if config_if();
  
  // Test memory
  logic [7:0] test_memory[0:255];
  
  // Test variables
  int test_pass_count;
  int test_fail_count;
  
  // DUT Instance
  nmp_sort_unit dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .core_if(core_if.nmp_unit),
    .mem_if(mem_if.nmp_unit),
    .config_if(config_if.nmp_unit)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Memory model
  always_ff @(posedge clk) begin
    if (mem_if.req && mem_if.gnt) begin
      if (mem_if.we) begin
        for (int i = 0; i < 4; i++) begin
          if (mem_if.be[i]) begin
            test_memory[mem_if.addr[7:0] + i] <= mem_if.wdata[i*8 +: 8];
          end
        end
      end
      mem_if.valid <= 1'b1;
      mem_if.rdata <= {test_memory[mem_if.addr[7:0] + 3],
                       test_memory[mem_if.addr[7:0] + 2],
                       test_memory[mem_if.addr[7:0] + 1],
                       test_memory[mem_if.addr[7:0]]};
    end else begin
      mem_if.valid <= 1'b0;
    end
  end
  
  assign mem_if.gnt = mem_if.req;
  assign mem_if.error = 1'b0;
  
  // Reset task
  task reset_system();
    begin
      rst_n = 0;
      core_if.req = 0;
      core_if.addr = 0;
      core_if.wdata = 0;
      core_if.we = 0;
      core_if.be = 4'hF;
      core_if.nmp_op = 3'b001; // SORT
      core_if.nmp_funct7 = 0;
      config_if.enable = 1;
      repeat(5) @(posedge clk);
      rst_n = 1;
      repeat(5) @(posedge clk);
    end
  endtask
  
  // Sort operation task
  task sort_array(
    input logic [31:0] addr,
    input logic [5:0] count,
    input logic ascending
  );
    begin
      @(posedge clk);
      core_if.req <= 1'b1;
      core_if.addr <= addr;
      core_if.nmp_funct7 <= {~ascending, count};
      
      wait(core_if.gnt);
      @(posedge clk);
      core_if.req <= 1'b0;
      
      wait(core_if.valid);
      @(posedge clk);
    end
  endtask
  
  // Check if array is sorted
  function logic check_sorted(
    input logic [7:0] start_addr,
    input int count,
    input logic ascending
  );
    logic sorted = 1'b1;
    for (int i = 0; i < count - 1; i++) begin
      if (ascending) begin
        if (test_memory[start_addr + i] > test_memory[start_addr + i + 1]) begin
          sorted = 1'b0;
        end
      end else begin
        if (test_memory[start_addr + i] < test_memory[start_addr + i + 1]) begin
          sorted = 1'b0;
        end
      end
    end
    return sorted;
  endfunction
  
  // Main test sequence
  initial begin
    $display("\n========================================");
    $display("NMP Sort Unit Testbench");
    $display("========================================\n");
    
    test_pass_count = 0;
    test_fail_count = 0;
    
    reset_system();
    
    // Test 1: Sort 16 elements ascending
    $display("Test 1: Sort 16 elements ascending");
    for (int i = 0; i < 16; i++) begin
      test_memory[i] = 16 - i; // Reverse order
    end
    
    sort_array(32'h00000000, 6'd16, 1'b1);
    
    if (check_sorted(0, 16, 1'b1)) begin
      $display("[PASS] 16 elements sorted ascending");
      test_pass_count++;
    end else begin
      $display("[FAIL] 16 elements not sorted correctly");
      test_fail_count++;
    end
    
    // Test 2: Sort 32 elements descending
    $display("\nTest 2: Sort 32 elements descending");
    for (int i = 0; i < 32; i++) begin
      test_memory[64 + i] = $random() & 8'hFF;
    end
    
    sort_array(32'h00000040, 6'd32, 1'b0);
    
    if (check_sorted(64, 32, 1'b0)) begin
      $display("[PASS] 32 elements sorted descending");
      test_pass_count++;
    end else begin
      $display("[FAIL] 32 elements not sorted correctly");
      test_fail_count++;
    end
    
    // Test 3: Sort already sorted array
    $display("\nTest 3: Sort already sorted array");
    for (int i = 0; i < 8; i++) begin
      test_memory[128 + i] = i;
    end
    
    sort_array(32'h00000080, 6'd8, 1'b1);
    
    if (check_sorted(128, 8, 1'b1)) begin
      $display("[PASS] Already sorted array handled correctly");
      test_pass_count++;
    end else begin
      $display("[FAIL] Already sorted array corrupted");
      test_fail_count++;
    end
    
    // Test 4: Sort single element (edge case)
    $display("\nTest 4: Sort single element");
    test_memory[160] = 8'h42;
    
    sort_array(32'h000000A0, 6'd1, 1'b1);
    
    if (test_memory[160] == 8'h42 && !core_if.error) begin
      $display("[PASS] Single element sort handled");
      test_pass_count++;
    end else begin
      $display("[FAIL] Single element sort failed");
      test_fail_count++;
    end
    
    // Display results
    $display("\n========================================");
    $display("Test Results:");
    $display("PASSED: %0d tests", test_pass_count);
    $display("FAILED: %0d tests", test_fail_count);
    $display("========================================\n");
    
    #100;
    $finish;
  end
  
  // Waveform dumping
  initial begin
    $dumpfile("tb_nmp_sort.vcd");
    $dumpvars(0, tb_nmp_sort);
  end

endmodule
