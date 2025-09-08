// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Map Unit                                   //
// Implements hardware-accelerated element-wise transformations           //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_map_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if
);

  // Map operation types
  typedef enum logic [2:0] {
    OP_SCALE    = 3'b000,  // Multiply by constant
    OP_ADD      = 3'b001,  // Add constant
    OP_SQUARE   = 3'b010,  // Square each element
    OP_ABS      = 3'b011,  // Absolute value
    OP_NEGATE   = 3'b100,  // Negate
    OP_SHIFT_L  = 3'b101,  // Left shift
    OP_SHIFT_R  = 3'b110   // Right shift
  } map_op_t;
  
  // Map operation states
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    FETCH,
    TRANSFORM,
    STORE,
    COMPLETE,
    ERROR
  } map_state_t;
  
  map_state_t current_state, next_state;
  
  // Configuration parameters from funct7
  typedef struct packed {
    logic [2:0] operation;     // Transformation operation
    logic [2:0] data_width;    // 000: 32-bit, 001: 16-bit, 010: 8-bit
    logic       in_place;      // 1: in-place, 0: copy to new location
  } map_config_t;
  
  map_config_t map_config;
  
  // Internal registers
  logic [31:0] src_addr_q, src_addr_d;         // Source address
  logic [31:0] dst_addr_q, dst_addr_d;         // Destination address (if not in-place)
  logic [31:0] array_size_q, array_size_d;    // Array size
  logic [31:0] transform_param_q, transform_param_d; // Transform parameter (scale, shift amount, etc.)
  logic [31:0] current_src_q, current_src_d;  // Current source address
  logic [31:0] current_dst_q, current_dst_d;  // Current destination address
  logic [31:0] index_q, index_d;              // Current index
  logic [31:0] fetched_data_q, fetched_data_d; // Data fetched from memory
  logic [31:0] transformed_data_q, transformed_data_d; // Transformed data
  logic        error_q, error_d;              // Error flag
  logic [7:0]  status_q, status_d;            // Status code
  
  // Performance counters
  logic [31:0] cycle_count_q, cycle_count_d;
  logic [31:0] memory_accesses_q, memory_accesses_d;
  logic [31:0] transformations_q, transformations_d;
  
  //////////////////////////////////////////////////////////////////////////////
  // Configuration Decoding
  //////////////////////////////////////////////////////////////////////////////
  
  assign map_config = map_config_t'(core_if.nmp_funct7);
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state       <= IDLE;
      src_addr_q          <= 32'h0;
      dst_addr_q          <= 32'h0;
      array_size_q        <= 32'h0;
      transform_param_q   <= 32'h1; // Default scale factor
      current_src_q       <= 32'h0;
      current_dst_q       <= 32'h0;
      index_q             <= 32'h0;
      fetched_data_q      <= 32'h0;
      transformed_data_q  <= 32'h0;
      error_q             <= 1'b0;
      status_q            <= 8'h00;
      cycle_count_q       <= 32'h0;
      memory_accesses_q   <= 32'h0;
      transformations_q   <= 32'h0;
    end else begin
      current_state       <= next_state;
      src_addr_q          <= src_addr_d;
      dst_addr_q          <= dst_addr_d;
      array_size_q        <= array_size_d;
      transform_param_q   <= transform_param_d;
      current_src_q       <= current_src_d;
      current_dst_q       <= current_dst_d;
      index_q             <= index_d;
      fetched_data_q      <= fetched_data_d;
      transformed_data_q  <= transformed_data_d;
      error_q             <= error_d;
      status_q            <= status_d;
      cycle_count_q       <= cycle_count_d;
      memory_accesses_q   <= memory_accesses_d;
      transformations_q   <= transformations_d;
    end
  end
  
  always_comb begin
    // Default assignments
    next_state          = current_state;
    src_addr_d          = src_addr_q;
    dst_addr_d          = dst_addr_q;
    array_size_d        = array_size_q;
    transform_param_d   = transform_param_q;
    current_src_d       = current_src_q;
    current_dst_d       = current_dst_q;
    index_d             = index_q;
    fetched_data_d      = fetched_data_q;
    transformed_data_d  = transformed_data_q;
    error_d             = error_q;
    status_d            = status_q;
    cycle_count_d       = cycle_count_q + 1;
    memory_accesses_d   = memory_accesses_q;
    transformations_d   = transformations_q;
    
    // Default outputs
    core_if.gnt         = 1'b0;
    core_if.valid       = 1'b0;
    core_if.ready       = 1'b1;
    core_if.rdata       = 32'h0;
    core_if.result      = index_q; // Return number of elements transformed
    core_if.error       = error_q;
    core_if.status      = status_q;
    core_if.cycle_count = cycle_count_q;
    core_if.busy        = (current_state != IDLE);
    
    // Memory interface defaults
    mem_if.req          = 1'b0;
    mem_if.addr         = current_src_q;
    mem_if.wdata        = 32'h0;
    mem_if.we           = 1'b0;
    mem_if.be           = 4'b1111;
    mem_if.id           = 8'h05; // Map unit ID
    mem_if.burst        = 1'b0;
    mem_if.burst_len    = 4'h1;
    
    case (current_state)
      IDLE: begin
        core_if.ready = 1'b1;
        if (core_if.req && config_if.enable) begin
          next_state = SETUP;
          core_if.gnt = 1'b1;
          // Capture operation parameters
          src_addr_d = core_if.addr;
          array_size_d = core_if.wdata; // Array size in wdata
          cycle_count_d = 32'h1;
        end
      end
      
      SETUP: begin
        // Initialize map parameters
        current_src_d = src_addr_q;
        if (map_config.in_place) begin
          current_dst_d = src_addr_q; // In-place transformation
          dst_addr_d = src_addr_q;
        end else begin
          // For simplicity, assume dst_addr = src_addr + array_size * 4
          dst_addr_d = src_addr_q + (array_size_q << 2);
          current_dst_d = dst_addr_q;
        end
        
        index_d = 32'h0;
        error_d = 1'b0;
        status_d = 8'h00;
        
        // Set default transformation parameter
        transform_param_d = 32'h2; // Example: scale by 2
        
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
          next_state = TRANSFORM;
        end
      end
      
      TRANSFORM: begin
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h10; // Memory error
          end else begin
            fetched_data_d = mem_if.rdata;
            transformations_d = transformations_q + 1;
            
            // Apply transformation based on operation type
            case (map_config.operation)
              OP_SCALE: begin
                transformed_data_d = fetched_data_q * transform_param_q;
              end
              
              OP_ADD: begin
                transformed_data_d = fetched_data_q + transform_param_q;
              end
              
              OP_SQUARE: begin
                transformed_data_d = fetched_data_q * fetched_data_q;
              end
              
              OP_ABS: begin
                if ($signed(fetched_data_q) < 0) begin
                  transformed_data_d = -$signed(fetched_data_q);
                end else begin
                  transformed_data_d = fetched_data_q;
                end
              end
              
              OP_NEGATE: begin
                transformed_data_d = -$signed(fetched_data_q);
              end
              
              OP_SHIFT_L: begin
                transformed_data_d = fetched_data_q << transform_param_q[4:0]; // Use lower 5 bits
              end
              
              OP_SHIFT_R: begin
                transformed_data_d = fetched_data_q >> transform_param_q[4:0]; // Use lower 5 bits
              end
              
              default: begin
                transformed_data_d = fetched_data_q; // Pass through
              end
            endcase
            
            next_state = STORE;
          end
        end
      end
      
      STORE: begin
        mem_if.req = 1'b1;
        mem_if.we = 1'b1;
        mem_if.addr = current_dst_q;
        mem_if.wdata = transformed_data_q;
        
        if (mem_if.gnt) begin
          memory_accesses_d = memory_accesses_q + 1;
        end
        
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h11; // Memory write error
          end else begin
            // Update indices and addresses
            index_d = index_q + 1;
            
            if (index_q >= (array_size_q - 1)) begin
              next_state = COMPLETE;
            end else begin
              // Move to next elements
              case (map_config.data_width)
                3'b000: begin // 32-bit
                  current_src_d = current_src_q + 4;
                  if (!map_config.in_place) begin
                    current_dst_d = current_dst_q + 4;
                  end else begin
                    current_dst_d = current_src_d;
                  end
                end
                3'b001: begin // 16-bit
                  current_src_d = current_src_q + 2;
                  if (!map_config.in_place) begin
                    current_dst_d = current_dst_q + 2;
                  end else begin
                    current_dst_d = current_src_d;
                  end
                end
                3'b010: begin // 8-bit
                  current_src_d = current_src_q + 1;
                  if (!map_config.in_place) begin
                    current_dst_d = current_dst_q + 1;
                  end else begin
                    current_dst_d = current_src_d;
                  end
                end
                default: begin // Default to 32-bit
                  current_src_d = current_src_q + 4;
                  if (!map_config.in_place) begin
                    current_dst_d = current_dst_q + 4;
                  end else begin
                    current_dst_d = current_src_d;
                  end
                end
              endcase
              next_state = FETCH;
            end
          end
        end
      end
      
      COMPLETE: begin
        core_if.valid = 1'b1;
        core_if.result = index_q;
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
    config_if.unit_status = {4'b0101, current_state}; // Unit ID=5, current state
    config_if.interrupt = (current_state == COMPLETE) || (current_state == ERROR);
  end

endmodule
