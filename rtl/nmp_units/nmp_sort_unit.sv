// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Sort Unit                                  //
// Implements hardware-accelerated sorting operations                      //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_sort_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if
);

  // Sort operation states
  typedef enum logic [3:0] {
    IDLE,
    SETUP,
    LOAD_ELEMENTS,
    BUBBLE_SORT,
    COMPARE_SWAP,
    WRITE_BACK,
    COMPLETE,
    ERROR
  } sort_state_t;
  
  sort_state_t current_state, next_state;
  
  // Configuration parameters from funct7
  typedef struct packed {
    logic [2:0] data_width;    // 000: 32-bit, 001: 16-bit, 010: 8-bit
    logic       ascending;     // 1: ascending, 0: descending
    logic [2:0] reserved;
  } sort_config_t;
  
  sort_config_t sort_config;
  
  // Internal registers
  logic [31:0] base_addr_q, base_addr_d;          // Base address
  logic [31:0] array_size_q, array_size_d;       // Array size (max 64 elements for bubble sort)
  logic [31:0] current_addr_q, current_addr_d;   // Current memory address
  logic [31:0] i_q, i_d;                         // Outer loop counter
  logic [31:0] j_q, j_d;                         // Inner loop counter
  logic        swap_needed_q, swap_needed_d;     // Swap flag
  logic        error_q, error_d;                 // Error flag
  logic [7:0]  status_q, status_d;               // Status code
  
  // Internal memory for small arrays (up to 64 elements)
  logic [31:0] sort_buffer [0:63];
  logic [5:0]  buffer_size_q, buffer_size_d;
  logic [5:0]  load_index_q, load_index_d;
  logic [5:0]  store_index_q, store_index_d;
  
  // Performance counters
  logic [31:0] cycle_count_q, cycle_count_d;
  logic [31:0] memory_accesses_q, memory_accesses_d;
  logic [31:0] comparisons_q, comparisons_d;
  logic [31:0] swaps_q, swaps_d;
  
  //////////////////////////////////////////////////////////////////////////////
  // Configuration Decoding
  //////////////////////////////////////////////////////////////////////////////
  
  assign sort_config = sort_config_t'(core_if.nmp_funct7);
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state      <= IDLE;
      base_addr_q        <= 32'h0;
      array_size_q       <= 32'h0;
      current_addr_q     <= 32'h0;
      i_q                <= 32'h0;
      j_q                <= 32'h0;
      swap_needed_q      <= 1'b0;
      error_q            <= 1'b0;
      status_q           <= 8'h00;
      buffer_size_q      <= 6'h0;
      load_index_q       <= 6'h0;
      store_index_q      <= 6'h0;
      cycle_count_q      <= 32'h0;
      memory_accesses_q  <= 32'h0;
      comparisons_q      <= 32'h0;
      swaps_q            <= 32'h0;
      
      // Initialize sort buffer to zero
      for (int k = 0; k < 64; k++) begin
        sort_buffer[k] <= 32'h0;
      end
    end else begin
      current_state      <= next_state;
      base_addr_q        <= base_addr_d;
      array_size_q       <= array_size_d;
      current_addr_q     <= current_addr_d;
      i_q                <= i_d;
      j_q                <= j_d;
      swap_needed_q      <= swap_needed_d;
      error_q            <= error_d;
      status_q           <= status_d;
      buffer_size_q      <= buffer_size_d;
      load_index_q       <= load_index_d;
      store_index_q      <= store_index_d;
      cycle_count_q      <= cycle_count_d;
      memory_accesses_q  <= memory_accesses_d;
      comparisons_q      <= comparisons_d;
      swaps_q            <= swaps_d;
      
      // Update sort buffer during load phase
      if (current_state == LOAD_ELEMENTS && mem_if.valid && !mem_if.error) begin
        sort_buffer[load_index_q] <= mem_if.rdata;
      end
      
      // Perform swaps during sort phase
      if (current_state == COMPARE_SWAP && swap_needed_d) begin
        sort_buffer[j_q] <= sort_buffer[j_q + 1];
        sort_buffer[j_q + 1] <= sort_buffer[j_q];
      end
    end
  end
  
  always_comb begin
    // Default assignments
    next_state         = current_state;
    base_addr_d        = base_addr_q;
    array_size_d       = array_size_q;
    current_addr_d     = current_addr_q;
    i_d                = i_q;
    j_d                = j_q;
    swap_needed_d      = swap_needed_q;
    error_d            = error_q;
    status_d           = status_q;
    buffer_size_d      = buffer_size_q;
    load_index_d       = load_index_q;
    store_index_d      = store_index_q;
    cycle_count_d      = cycle_count_q + 1;
    memory_accesses_d  = memory_accesses_q;
    comparisons_d      = comparisons_q;
    swaps_d            = swaps_q;
    
    // Default outputs
    core_if.gnt        = 1'b0;
    core_if.valid      = 1'b0;
    core_if.ready      = 1'b1;
    core_if.rdata      = 32'h0;
    core_if.result     = array_size_q; // Return number of elements sorted
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
    mem_if.id          = 8'h02; // Sort unit ID
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
          array_size_d = core_if.wdata; // Array size passed in wdata
          cycle_count_d = 32'h1;
        end
      end
      
      SETUP: begin
        // Check if array size is within our buffer limits
        if (array_size_q > 64) begin
          next_state = ERROR;
          error_d = 1'b1;
          status_d = 8'h20; // Array too large
        end else if (array_size_q == 0) begin
          next_state = COMPLETE;
        end else begin
          // Initialize counters
          current_addr_d = base_addr_q;
          buffer_size_d = array_size_q[5:0];
          load_index_d = 6'h0;
          store_index_d = 6'h0;
          i_d = 32'h0;
          j_d = 32'h0;
          next_state = LOAD_ELEMENTS;
        end
      end
      
      LOAD_ELEMENTS: begin
        mem_if.req = 1'b1;
        if (mem_if.gnt) begin
          memory_accesses_d = memory_accesses_q + 1;
        end
        
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h10; // Memory error
          end else begin
            load_index_d = load_index_q + 1;
            
            if (load_index_q >= (buffer_size_q - 1)) begin
              // All elements loaded, start sorting
              next_state = BUBBLE_SORT;
              i_d = 32'h0;
            end else begin
              // Load next element
              case (sort_config.data_width)
                3'b000: current_addr_d = current_addr_q + 4; // 32-bit
                3'b001: current_addr_d = current_addr_q + 2; // 16-bit  
                3'b010: current_addr_d = current_addr_q + 1; // 8-bit
                default: current_addr_d = current_addr_q + 4;
              endcase
            end
          end
        end
      end
      
      BUBBLE_SORT: begin
        // Outer loop of bubble sort
        if (i_q < (buffer_size_q - 1)) begin
          j_d = 32'h0;
          next_state = COMPARE_SWAP;
        end else begin
          // Sorting complete, write back to memory
          current_addr_d = base_addr_q;
          store_index_d = 6'h0;
          next_state = WRITE_BACK;
        end
      end
      
      COMPARE_SWAP: begin
        // Inner loop of bubble sort
        if (j_q < (buffer_size_q - i_q - 1)) begin
          comparisons_d = comparisons_q + 1;
          
          // Compare adjacent elements
          if (should_swap(sort_buffer[j_q], sort_buffer[j_q + 1], sort_config)) begin
            swap_needed_d = 1'b1;
            swaps_d = swaps_q + 1;
          end else begin
            swap_needed_d = 1'b0;
          end
          
          j_d = j_q + 1;
        end else begin
          // Inner loop complete, increment outer loop
          i_d = i_q + 1;
          next_state = BUBBLE_SORT;
        end
      end
      
      WRITE_BACK: begin
        mem_if.req = 1'b1;
        mem_if.we = 1'b1;
        mem_if.wdata = sort_buffer[store_index_q];
        
        if (mem_if.gnt) begin
          memory_accesses_d = memory_accesses_q + 1;
        end
        
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h11; // Memory write error
          end else begin
            store_index_d = store_index_q + 1;
            
            if (store_index_q >= (buffer_size_q - 1)) begin
              // All elements written back
              next_state = COMPLETE;
            end else begin
              // Write next element
              case (sort_config.data_width)
                3'b000: current_addr_d = current_addr_q + 4; // 32-bit
                3'b001: current_addr_d = current_addr_q + 2; // 16-bit
                3'b010: current_addr_d = current_addr_q + 1; // 8-bit
                default: current_addr_d = current_addr_q + 4;
              endcase
            end
          end
        end
      end
      
      COMPLETE: begin
        core_if.valid = 1'b1;
        core_if.result = array_size_q;
        status_d = 8'h00; // Success
        next_state = IDLE;
      end
      
      ERROR: begin
        core_if.valid = 1'b1;
        core_if.error = 1'b1;
        core_if.result = 32'h0;
        next_state = IDLE;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Comparison Function
  //////////////////////////////////////////////////////////////////////////////
  
  function automatic logic should_swap(
    input logic [31:0] a,
    input logic [31:0] b,
    input sort_config_t config
  );
    logic result;
    
    case (config.data_width)
      3'b000: begin // 32-bit comparison
        if (config.ascending) begin
          result = (a > b);
        end else begin
          result = (a < b);
        end
      end
      
      3'b001: begin // 16-bit comparison
        if (config.ascending) begin
          result = (a[15:0] > b[15:0]);
        end else begin
          result = (a[15:0] < b[15:0]);
        end
      end
      
      3'b010: begin // 8-bit comparison
        if (config.ascending) begin
          result = (a[7:0] > b[7:0]);
        end else begin
          result = (a[7:0] < b[7:0]);
        end
      end
      
      default: begin
        if (config.ascending) begin
          result = (a > b);
        end else begin
          result = (a < b);
        end
      end
    endcase
    
    return result;
  endfunction
  
  //////////////////////////////////////////////////////////////////////////////
  // Performance Counter Interface
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    config_if.perf_counter = cycle_count_q;
    config_if.unit_status = {4'b0010, current_state}; // Unit ID=2, current state
    config_if.interrupt = (current_state == COMPLETE) || (current_state == ERROR);
  end

endmodule
