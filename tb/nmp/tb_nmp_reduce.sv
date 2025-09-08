// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// NMP Reduce Unit Testbench                                                //
// Tests all reduction operations (SUM, PRODUCT, MIN, MAX, AND, OR, XOR)    //
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_nmp_reduce;

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
  
  // Reduce operation types
  localparam REDUCE_SUM     = 3'b000;
  localparam REDUCE_PRODUCT = 3'b001;
  localparam REDUCE_MIN     = 3'b010;
  localparam REDUCE_MAX     = 3'b011;
  localparam REDUCE_AND     = 3'b100;
  localparam REDUCE_OR      = 3'b101;
  localparam REDUCE_XOR     = 3'b110;
  
  // DUT Instance
  nmp_reduce_unit dut (
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
      core_if.nmp_op = 3'b010; // REDUCE
      core_if.nmp_funct7 = 0;
      config_if.enable = 1;
      repeat(5) @(posedge clk);
      rst_n = 1;
      repeat(5) @(posedge clk);
    end
  endtask
  
  // Reduce operation task
  task reduce_operation(
    input logic [31:0] addr,
    input logic [31:0] count,
    input logic [2:0] op_type,
    output logic [31:0] result
  );
    begin
      @(posedge clk);
      core_if.req <= 1'b1;
      core_if.addr <= addr;
      core_if.wdata <= count; // Number of elements
      core_if.nmp_funct7 <= {op_type, 4'b0000};
      
      wait(core_if.gnt);
      @(posedge clk);
      core_if.req <= 1'b0;
      
      wait(core_if.valid);
      result = core_if.result;
      @(posedge clk);
    end
  endtask
  
  // Calculate expected result
  function logic [31:0] calculate_expected(
    input logic [7:0] start_addr,
    input int count,
    input logic [2:0] op_type
  );
    logic [31:0] result;
    
    case (op_type)
      REDUCE_SUM: begin
        result = 0;
        for (int i = 0; i < count; i++) begin
          result = result + test_memory[start_addr + i];
        end
      end
      
      REDUCE_PRODUCT: begin
        result = 1;
        for (int i = 0; i < count && i < 4; i++) begin // Limit to prevent overflow
          result = result * test_memory[start_addr + i];
        end
      end
      
      REDUCE_MIN: begin
        result = 32'hFFFFFFFF;
        for (int i = 0; i < count; i++) begin
          if (test_memory[start_addr + i] < result[7:0])
            result = test_memory[start_addr + i];
        end
      end
      
      REDUCE_MAX: begin
        result = 0;
        for (int i = 0; i < count; i++) begin
          if (test_memory[start_addr + i] > result[7:0])
            result = test_memory[start_addr + i];
        end
      end
      
      REDUCE_AND: begin
        result = 32'hFFFFFFFF;
        for (int i = 0; i < count; i++) begin
          result = result & test_memory[start_addr + i];
        end
      end
      
      REDUCE_OR: begin
        result = 0;
        for (int i = 0; i < count; i++) begin
          result = result | test_memory[start_addr + i];
        end
      end
      
      REDUCE_XOR: begin
        result = 0;
        for (int i = 0; i < count; i++) begin
          result = result ^ test_memory[start_addr + i];
        end
      end
      
      default: result = 0;
    endcase
    
    return result;
  endfunction
  
  // Main test sequence
  initial begin
    logic [31:0] result;
    logic [31:0] expected;
    
    $display("\n========================================");
    $display("NMP Reduce Unit Testbench");
    $display("========================================\n");
    
    test_pass_count = 0;
    test_fail_count = 0;
    
    reset_system();
    
    // Initialize test data
    for (int i = 0; i < 256; i++) begin
      test_memory[i] = (i % 16) + 1; // Values 1-16 repeating
    end
    
    // Test 1: SUM operation
    $display("Test 1: SUM operation (16 elements)");
    expected = calculate_expected(0, 16, REDUCE_SUM);
    reduce_operation(32'h00000000, 32'd16, REDUCE_SUM, result);
    
    if (result == expected && !core_if.error) begin
      $display("[PASS] SUM = %0d (expected %0d)", result, expected);
      test_pass_count++;
    end else begin
      $display("[FAIL] SUM = %0d (expected %0d)", result, expected);
      test_fail_count++;
    end
    
    // Test 2: MIN operation
    $display("\nTest 2: MIN operation (32 elements)");
    expected = calculate_expected(0, 32, REDUCE_MIN);
    reduce_operation(32'h00000000, 32'd32, REDUCE_MIN, result);
    
    if (result == expected && !core_if.error) begin
      $display("[PASS] MIN = %0d (expected %0d)", result, expected);
      test_pass_count++;
    end else begin
      $display("[FAIL] MIN = %0d (expected %0d)", result, expected);
      test_fail_count++;
    end
    
    // Test 3: MAX operation
    $display("\nTest 3: MAX operation (32 elements)");
    expected = calculate_expected(0, 32, REDUCE_MAX);
    reduce_operation(32'h00000000, 32'd32, REDUCE_MAX, result);
    
    if (result == expected && !core_if.error) begin
      $display("[PASS] MAX = %0d (expected %0d)", result, expected);
      test_pass_count++;
    end else begin
      $display("[FAIL] MAX = %0d (expected %0d)", result, expected);
      test_fail_count++;
    end
    
    // Test 4: AND operation
    $display("\nTest 4: AND operation (8 elements)");
    for (int i = 64; i < 72; i++) begin
      test_memory[i] = 8'hFF; // All bits set
    end
    test_memory[68] = 8'hF0; // Clear some bits
    
    expected = 8'hF0;
    reduce_operation(32'h00000040, 32'd8, REDUCE_AND, result);
    
    if (result[7:0] == expected[7:0] && !core_if.error) begin
      $display("[PASS] AND = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_pass_count++;
    end else begin
      $display("[FAIL] AND = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_fail_count++;
    end
    
    // Test 5: OR operation
    $display("\nTest 5: OR operation (8 elements)");
    for (int i = 80; i < 88; i++) begin
      test_memory[i] = 1 << (i % 8); // Different bits set
    end
    
    expected = 8'hFF;
    reduce_operation(32'h00000050, 32'd8, REDUCE_OR, result);
    
    if (result[7:0] == expected[7:0] && !core_if.error) begin
      $display("[PASS] OR = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_pass_count++;
    end else begin
      $display("[FAIL] OR = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_fail_count++;
    end
    
    // Test 6: XOR operation
    $display("\nTest 6: XOR operation (4 elements)");
    test_memory[96] = 8'hAA;
    test_memory[97] = 8'h55;
    test_memory[98] = 8'hFF;
    test_memory[99] = 8'h00;
    
    expected = 8'hAA ^ 8'h55 ^ 8'hFF ^ 8'h00;
    reduce_operation(32'h00000060, 32'd4, REDUCE_XOR, result);
    
    if (result[7:0] == expected[7:0] && !core_if.error) begin
      $display("[PASS] XOR = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_pass_count++;
    end else begin
      $display("[FAIL] XOR = 0x%02x (expected 0x%02x)", result[7:0], expected[7:0]);
      test_fail_count++;
    end
    
    // Test 7: PRODUCT operation (small values to avoid overflow)
    $display("\nTest 7: PRODUCT operation (4 elements)");
    test_memory[112] = 2;
    test_memory[113] = 3;
    test_memory[114] = 4;
    test_memory[115] = 5;
    
    expected = 2 * 3 * 4 * 5; // = 120
    reduce_operation(32'h00000070, 32'd4, REDUCE_PRODUCT, result);
    
    if (result == expected && !core_if.error) begin
      $display("[PASS] PRODUCT = %0d (expected %0d)", result, expected);
      test_pass_count++;
    end else begin
      $display("[FAIL] PRODUCT = %0d (expected %0d)", result, expected);
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
    $dumpfile("tb_nmp_reduce.vcd");
    $dumpvars(0, tb_nmp_reduce);
  end

endmodule
