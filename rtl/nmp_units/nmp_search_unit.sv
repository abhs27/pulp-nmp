// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Search Unit                                //
// Implements hardware-accelerated linear search operations                //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_search_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if
);

  // Search operation states
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    FETCH,
    COMPARE,
    NEXT,
    FOUND,
    NOT_FOUND
  } search_state_t;
  
  search_state_t current_state, next_state;
  
  // Configuration parameters from funct7
  typedef struct packed {
    logic [2:0] data_width;    // 000: 32-bit, 001: 16-bit, 010: 8-bit
    logic       exact_match;   // 1: exact match, 0: pattern match
    logic       ascending;     // Search direction
    logic [1:0] reserved;
  } search_config_t;
  
  search_config_t search_config;
  
  // Internal registers
  logic [31:0] base_addr_q, base_addr_d;      // Base address
  logic [31:0] search_value_q, search_value_d; // Value to search for
  logic [31:0] current_addr_q, current_addr_d; // Current search address
  logic [31:0] array_size_q, array_size_d;    // Array size
  logic [31:0] index_q, index_d;              // Current index
  logic [31:0] result_q, result_d;            // Search result (index or -1)
  logic [31:0] fetched_data_q, fetched_data_d; // Data fetched from memory
  logic        found_q, found_d;              // Found flag
  logic        error_q, error_d;              // Error flag
  logic [7:0]  status_q, status_d;            // Status code
  
  // Performance counters
  logic [31:0] cycle_count_q, cycle_count_d;
  logic [31:0] memory_accesses_q, memory_accesses_d;
  logic [31:0] comparisons_q, comparisons_d;
  
  //////////////////////////////////////////////////////////////////////////////
  // Configuration Decoding
  //////////////////////////////////////////////////////////////////////////////
  
  assign search_config = search_config_t'(core_if.nmp_funct7);
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state      <= IDLE;
      base_addr_q        <= 32'h0;
      search_value_q     <= 32'h0;
      current_addr_q     <= 32'h0;
      array_size_q       <= 32'h0;
      index_q            <= 32'h0;
      result_q           <= 32'hFFFFFFFF; // -1 (not found)
      fetched_data_q     <= 32'h0;
      found_q            <= 1'b0;
      error_q            <= 1'b0;
      status_q           <= 8'h00;
      cycle_count_q      <= 32'h0;
      memory_accesses_q  <= 32'h0;
      comparisons_q      <= 32'h0;
    end else begin
      current_state      <= next_state;
      base_addr_q        <= base_addr_d;
      search_value_q     <= search_value_d;
      current_addr_q     <= current_addr_d;
      array_size_q       <= array_size_d;
      index_q            <= index_d;
      result_q           <= result_d;
      fetched_data_q     <= fetched_data_d;
      found_q            <= found_d;
      error_q            <= error_d;
      status_q           <= status_d;
      cycle_count_q      <= cycle_count_d;
      memory_accesses_q  <= memory_accesses_d;
      comparisons_q      <= comparisons_d;
    end
  end
  
  always_comb begin
    // Default assignments
    next_state         = current_state;
    base_addr_d        = base_addr_q;
    search_value_d     = search_value_q;
    current_addr_d     = current_addr_q;
    array_size_d       = array_size_q;
    index_d            = index_q;
    result_d           = result_q;
    fetched_data_d     = fetched_data_q;
    found_d            = found_q;
    error_d            = error_q;
    status_d           = status_q;
    cycle_count_d      = cycle_count_q + 1;
    memory_accesses_d  = memory_accesses_q;
    comparisons_d      = comparisons_q;
    
    // Default outputs
    core_if.gnt        = 1'b0;
    core_if.valid      = 1'b0;
    core_if.ready      = 1'b1;
    core_if.rdata      = 32'h0;
    core_if.result     = result_q;
    core_if.error      = error_q;
    core_if.status     = status_q;
    core_if.cycle_count = cycle_count_q;
    core_if.busy       = (current_state != IDLE);
    
    // Memory interface defaults
    mem_if.req         = 1'b0;
    mem_if.addr        = current_addr_q;
    mem_if.wdata       = 32'h0;
    mem_if.we          = 1'b0;
    mem_if.be          = 4'b1111;
    mem_if.id          = 8'h01; // Search unit ID
    mem_if.burst       = 1'b0;
    mem_if.burst_len   = 4'h1;
    
    case (current_state)
      IDLE: begin
        core_if.ready = 1'b1;
        if (core_if.req && config_if.enable) begin
          next_state = SETUP;
          core_if.gnt = 1'b1;
          // Capture operation parameters
          base_addr_d = core_if.addr;
          search_value_d = core_if.wdata;
          // Array size is passed in rs2 (would be in second register)
          array_size_d = 32'h100; // Default size for now
          cycle_count_d = 32'h1;
        end
      end
      
      SETUP: begin
        // Initialize search parameters
        current_addr_d = base_addr_q;
        index_d = 32'h0;
        found_d = 1'b0;
        error_d = 1'b0;
        status_d = 8'h00;
        result_d = 32'hFFFFFFFF; // Initialize as not found
        next_state = FETCH;
      end
      
      FETCH: begin
        mem_if.req = 1'b1;
        if (mem_if.gnt) begin
          memory_accesses_d = memory_accesses_q + 1;
          next_state = COMPARE;
        end
      end
      
      COMPARE: begin
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = NOT_FOUND;
            error_d = 1'b1;
            status_d = 8'h10; // Memory error
          end else begin
            fetched_data_d = mem_if.rdata;
            comparisons_d = comparisons_q + 1;
            
            // Perform comparison based on data width and match type
            if (compare_values(fetched_data_q, search_value_q, search_config)) begin
              next_state = FOUND;
              found_d = 1'b1;
              result_d = index_q;
            end else begin
              next_state = NEXT;
            end
          end
        end
      end
      
      NEXT: begin
        // Check if we've reached the end of the array
        if (index_q >= (array_size_q - 1)) begin
          next_state = NOT_FOUND;
        end else begin
          // Move to next element
          case (search_config.data_width)
            3'b000: current_addr_d = current_addr_q + 4; // 32-bit
            3'b001: current_addr_d = current_addr_q + 2; // 16-bit
            3'b010: current_addr_d = current_addr_q + 1; // 8-bit
            default: current_addr_d = current_addr_q + 4;
          endcase
          index_d = index_q + 1;
          next_state = FETCH;
        end
      end
      
      FOUND: begin
        core_if.valid = 1'b1;
        core_if.result = result_q;
        status_d = 8'h00; // Success - found
        next_state = IDLE;
      end
      
      NOT_FOUND: begin
        core_if.valid = 1'b1;
        core_if.result = 32'hFFFFFFFF; // -1
        if (!error_q) begin
          status_d = 8'h01; // Not found
        end
        next_state = IDLE;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Comparison Function
  //////////////////////////////////////////////////////////////////////////////
  
  function automatic logic compare_values(
    input logic [31:0] fetched_data,
    input logic [31:0] search_value,
    input search_config_t config
  );
    logic result;
    
    case (config.data_width)
      3'b000: begin // 32-bit comparison
        if (config.exact_match) begin
          result = (fetched_data == search_value);
        end else begin
          // Pattern match - simple mask-based comparison
          // Upper 16 bits of search_value used as mask
          logic [31:0] mask = {search_value[31:16], 16'h0000};
          result = ((fetched_data & mask) == (search_value & mask));
        end
      end
      
      3'b001: begin // 16-bit comparison
        if (config.exact_match) begin
          result = (fetched_data[15:0] == search_value[15:0]);
        end else begin
          logic [15:0] mask = search_value[31:16];
          result = ((fetched_data[15:0] & mask) == (search_value[15:0] & mask));
        end
      end
      
      3'b010: begin // 8-bit comparison
        if (config.exact_match) begin
          result = (fetched_data[7:0] == search_value[7:0]);
        end else begin
          logic [7:0] mask = search_value[15:8];
          result = ((fetched_data[7:0] & mask) == (search_value[7:0] & mask));
        end
      end
      
      default: result = (fetched_data == search_value);
    endcase
    
    return result;
  endfunction
  
  //////////////////////////////////////////////////////////////////////////////
  // Performance Counter Interface
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    config_if.perf_counter = cycle_count_q;
    config_if.unit_status = {4'b0001, current_state, found_q}; // Unit ID=1, state, found flag
    config_if.interrupt = (current_state == FOUND) || (current_state == NOT_FOUND && error_q);
  end

endmodule
