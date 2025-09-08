// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Filter Unit                                //
// Implements hardware-accelerated data filtering operations              //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_filter_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if
);

  // Simple filter implementation - range-based filtering
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    FETCH,
    FILTER,
    STORE,
    COMPLETE,
    ERROR
  } filter_state_t;
  
  filter_state_t current_state, next_state;
  
  // Configuration parameters from funct7
  typedef struct packed {
    logic [2:0] filter_type;   // 000: range, 001: threshold, etc.
    logic [2:0] data_width;    // 000: 32-bit, 001: 16-bit, 010: 8-bit
    logic       in_place;      // 1: in-place, 0: copy to new location
  } filter_config_t;
  
  filter_config_t filter_config;
  
  // Internal registers
  logic [31:0] src_addr_q, src_addr_d;         // Source address
  logic [31:0] dst_addr_q, dst_addr_d;         // Destination address (if not in-place)
  logic [31:0] array_size_q, array_size_d;    // Array size
  logic [31:0] min_value_q, min_value_d;      // Filter min value
  logic [31:0] max_value_q, max_value_d;      // Filter max value
  logic [31:0] current_src_q, current_src_d;  // Current source address
  logic [31:0] current_dst_q, current_dst_d;  // Current destination address
  logic [31:0] index_q, index_d;              // Current index
  logic [31:0] passed_count_q, passed_count_d; // Count of elements that passed filter
  logic [31:0] fetched_data_q, fetched_data_d; // Data fetched from memory
  logic        filter_pass_q, filter_pass_d;  // Current element passes filter
  logic        error_q, error_d;              // Error flag
  logic [7:0]  status_q, status_d;            // Status code
  
  // Performance counters
  logic [31:0] cycle_count_q, cycle_count_d;
  logic [31:0] memory_accesses_q, memory_accesses_d;
  logic [31:0] comparisons_q, comparisons_d;
  
  //////////////////////////////////////////////////////////////////////////////
  // Configuration Decoding
  //////////////////////////////////////////////////////////////////////////////
  
  assign filter_config = filter_config_t'(core_if.nmp_funct7);
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state      <= IDLE;
      src_addr_q         <= 32'h0;
      dst_addr_q         <= 32'h0;
      array_size_q       <= 32'h0;
      min_value_q        <= 32'h0;
      max_value_q        <= 32'hFFFFFFFF;
      current_src_q      <= 32'h0;
      current_dst_q      <= 32'h0;
      index_q            <= 32'h0;
      passed_count_q     <= 32'h0;
      fetched_data_q     <= 32'h0;
      filter_pass_q      <= 1'b0;
      error_q            <= 1'b0;
      status_q           <= 8'h00;
      cycle_count_q      <= 32'h0;
      memory_accesses_q  <= 32'h0;
      comparisons_q      <= 32'h0;
    end else begin
      current_state      <= next_state;
      src_addr_q         <= src_addr_d;
      dst_addr_q         <= dst_addr_d;
      array_size_q       <= array_size_d;
      min_value_q        <= min_value_d;
      max_value_q        <= max_value_d;
      current_src_q      <= current_src_d;
      current_dst_q      <= current_dst_d;
      index_q            <= index_d;
      passed_count_q     <= passed_count_d;
      fetched_data_q     <= fetched_data_d;
      filter_pass_q      <= filter_pass_d;
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
    src_addr_d         = src_addr_q;
    dst_addr_d         = dst_addr_q;
    array_size_d       = array_size_q;
    min_value_d        = min_value_q;
    max_value_d        = max_value_q;
    current_src_d      = current_src_q;
    current_dst_d      = current_dst_q;
    index_d            = index_q;
    passed_count_d     = passed_count_q;
    fetched_data_d     = fetched_data_q;
    filter_pass_d      = filter_pass_q;
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
    core_if.result     = passed_count_q; // Return count of elements that passed
    core_if.error      = error_q;
    core_if.status     = status_q;
    core_if.cycle_count = cycle_count_q;
    core_if.busy       = (current_state != IDLE);
    
    // Memory interface defaults
    mem_if.req         = 1'b0;
    mem_if.addr        = current_src_q;
    mem_if.wdata       = 32'h0;
    mem_if.we          = 1'b0;
    mem_if.be          = 4'b1111;
    mem_if.id          = 8'h04; // Filter unit ID
    mem_if.burst       = 1'b0;
    mem_if.burst_len   = 4'h1;
    
    case (current_state)
      IDLE: begin
        core_if.ready = 1'b1;
        if (core_if.req && config_if.enable) begin
          next_state = SETUP;
          core_if.gnt = 1'b1;
          // Capture operation parameters
          src_addr_d = core_if.addr;
          array_size_d = core_if.wdata; // Array size in wdata for simplicity
          cycle_count_d = 32'h1;
        end
      end
      
      SETUP: begin
        // Initialize filter parameters
        current_src_d = src_addr_q;
        if (filter_config.in_place) begin
          current_dst_d = src_addr_q; // In-place filtering
          dst_addr_d = src_addr_q;
        end else begin
          // For simplicity, assume dst_addr = src_addr + array_size * 4
          dst_addr_d = src_addr_q + (array_size_q << 2);
          current_dst_d = dst_addr_q;
        end
        
        index_d = 32'h0;
        passed_count_d = 32'h0;
        error_d = 1'b0;
        status_d = 8'h00;
        
        // Set default filter range (configurable through CSRs in real implementation)
        min_value_d = 32'h0000;
        max_value_d = 32'h1000; // Example range
        
        if (array_size_q == 0) begin
          next_state = COMPLETE;
        end else begin
          next_state = FETCH;
        end
      end
      
      FETCH: begin
        mem_if.req = 1'b1;
        if (mem_if.gnt) begin
          memory_accesses_d = memory_accesses_q + 1;
          next_state = FILTER;
        end
      end
      
      FILTER: begin
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h10; // Memory error
          end else begin
            fetched_data_d = mem_if.rdata;
            comparisons_d = comparisons_q + 1;
            
            // Apply filter based on type
            case (filter_config.filter_type)
              3'b000: begin // Range filter
                filter_pass_d = (fetched_data_q >= min_value_q) && 
                               (fetched_data_q <= max_value_q);
              end
              3'b001: begin // Threshold filter  
                filter_pass_d = (fetched_data_q >= min_value_q);
              end
              default: begin
                filter_pass_d = 1'b1; // Pass all by default
              end
            endcase
            
            if (filter_pass_q) begin
              next_state = STORE;
              passed_count_d = passed_count_q + 1;
            end else begin
              // Skip this element, move to next
              index_d = index_q + 1;
              if (index_q >= (array_size_q - 1)) begin
                next_state = COMPLETE;
              end else begin
                case (filter_config.data_width)
                  3'b000: current_src_d = current_src_q + 4; // 32-bit
                  3'b001: current_src_d = current_src_q + 2; // 16-bit
                  3'b010: current_src_d = current_src_q + 1; // 8-bit
                  default: current_src_d = current_src_q + 4;
                endcase
                next_state = FETCH;
              end
            end
          end
        end
      end
      
      STORE: begin
        if (filter_config.in_place) begin
          // For in-place, just move to next element (simplified)
          next_state = FETCH;
        end else begin
          // Store filtered element to destination
          mem_if.req = 1'b1;
          mem_if.we = 1'b1;
          mem_if.addr = current_dst_q;
          mem_if.wdata = fetched_data_q;
          
          if (mem_if.gnt) begin
            memory_accesses_d = memory_accesses_q + 1;
          end
          
          if (mem_if.valid) begin
            if (mem_if.error) begin
              next_state = ERROR;
              error_d = 1'b1;
              status_d = 8'h11; // Memory write error
            end else begin
              // Move destination pointer
              case (filter_config.data_width)
                3'b000: current_dst_d = current_dst_q + 4; // 32-bit
                3'b001: current_dst_d = current_dst_q + 2; // 16-bit
                3'b010: current_dst_d = current_dst_q + 1; // 8-bit
                default: current_dst_d = current_dst_q + 4;
              endcase
              next_state = FETCH; // Continue with next element
            end
          end
        end
        
        // Update source pointer and index
        index_d = index_q + 1;
        if (index_q >= (array_size_q - 1)) begin
          next_state = COMPLETE;
        end else begin
          case (filter_config.data_width)
            3'b000: current_src_d = current_src_q + 4; // 32-bit
            3'b001: current_src_d = current_src_q + 2; // 16-bit
            3'b010: current_src_d = current_src_q + 1; // 8-bit
            default: current_src_d = current_src_q + 4;
          endcase
        end
      end
      
      COMPLETE: begin
        core_if.valid = 1'b1;
        core_if.result = passed_count_q;
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
  // Performance Counter Interface
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    config_if.perf_counter = cycle_count_q;
    config_if.unit_status = {4'b0100, current_state, filter_pass_q}; // Unit ID=4, state, filter result
    config_if.interrupt = (current_state == COMPLETE) || (current_state == ERROR);
  end

endmodule
