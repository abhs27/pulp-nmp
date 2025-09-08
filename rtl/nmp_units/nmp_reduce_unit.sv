// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Reduce Unit                                //
// Implements hardware-accelerated reduction operations                    //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_reduce_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if
);

  // Reduce operation types
  typedef enum logic [2:0] {
    OP_SUM     = 3'b000,
    OP_PRODUCT = 3'b001,
    OP_MIN     = 3'b010,
    OP_MAX     = 3'b011,
    OP_AND     = 3'b100,
    OP_OR      = 3'b101,
    OP_XOR     = 3'b110
  } reduce_op_t;
  
  // Reduce operation states
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    FETCH,
    COMPUTE,
    COMPLETE,
    ERROR
  } reduce_state_t;
  
  reduce_state_t current_state, next_state;
  
  // Configuration parameters from funct7
  typedef struct packed {
    logic [2:0] operation;     // Reduction operation type
    logic [2:0] data_width;    // 000: 32-bit, 001: 16-bit, 010: 8-bit
    logic       reserved;
  } reduce_config_t;
  
  reduce_config_t reduce_config;
  
  // Internal registers
  logic [31:0] base_addr_q, base_addr_d;        // Base address
  logic [31:0] array_size_q, array_size_d;     // Array size
  logic [31:0] current_addr_q, current_addr_d; // Current memory address
  logic [31:0] index_q, index_d;               // Current index
  logic [31:0] accumulator_q, accumulator_d;   // Accumulation result
  logic [31:0] fetched_data_q, fetched_data_d; // Data fetched from memory
  logic        error_q, error_d;               // Error flag
  logic [7:0]  status_q, status_d;             // Status code
  logic        overflow_q, overflow_d;         // Overflow flag
  
  // Performance counters
  logic [31:0] cycle_count_q, cycle_count_d;
  logic [31:0] memory_accesses_q, memory_accesses_d;
  logic [31:0] operations_q, operations_d;
  
  //////////////////////////////////////////////////////////////////////////////
  // Configuration Decoding
  //////////////////////////////////////////////////////////////////////////////
  
  assign reduce_config = reduce_config_t'(core_if.nmp_funct7);
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state      <= IDLE;
      base_addr_q        <= 32'h0;
      array_size_q       <= 32'h0;
      current_addr_q     <= 32'h0;
      index_q            <= 32'h0;
      accumulator_q      <= 32'h0;
      fetched_data_q     <= 32'h0;
      error_q            <= 1'b0;
      status_q           <= 8'h00;
      overflow_q         <= 1'b0;
      cycle_count_q      <= 32'h0;
      memory_accesses_q  <= 32'h0;
      operations_q       <= 32'h0;
    end else begin
      current_state      <= next_state;
      base_addr_q        <= base_addr_d;
      array_size_q       <= array_size_d;
      current_addr_q     <= current_addr_d;
      index_q            <= index_d;
      accumulator_q      <= accumulator_d;
      fetched_data_q     <= fetched_data_d;
      error_q            <= error_d;
      status_q           <= status_d;
      overflow_q         <= overflow_d;
      cycle_count_q      <= cycle_count_d;
      memory_accesses_q  <= memory_accesses_d;
      operations_q       <= operations_d;
    end
  end
  
  always_comb begin
    // Default assignments
    next_state         = current_state;
    base_addr_d        = base_addr_q;
    array_size_d       = array_size_q;
    current_addr_d     = current_addr_q;
    index_d            = index_q;
    accumulator_d      = accumulator_q;
    fetched_data_d     = fetched_data_q;
    error_d            = error_q;
    status_d           = status_q;
    overflow_d         = overflow_q;
    cycle_count_d      = cycle_count_q + 1;
    memory_accesses_d  = memory_accesses_q;
    operations_d       = operations_q;
    
    // Default outputs
    core_if.gnt        = 1'b0;
    core_if.valid      = 1'b0;
    core_if.ready      = 1'b1;
    core_if.rdata      = 32'h0;
    core_if.result     = accumulator_q;
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
    mem_if.id          = 8'h03; // Reduce unit ID
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
        // Initialize reduction parameters
        current_addr_d = base_addr_q;
        index_d = 32'h0;
        error_d = 1'b0;
        status_d = 8'h00;
        overflow_d = 1'b0;
        
        // Initialize accumulator based on operation type
        case (reduce_config.operation)
          OP_SUM, OP_XOR: accumulator_d = 32'h0;
          OP_PRODUCT:     accumulator_d = 32'h1;
          OP_MIN:         accumulator_d = 32'hFFFFFFFF; // Max value for signed
          OP_MAX:         accumulator_d = 32'h80000000; // Min value for signed  
          OP_AND:         accumulator_d = 32'hFFFFFFFF; // All ones
          OP_OR:          accumulator_d = 32'h0;
          default:        accumulator_d = 32'h0;
        endcase
        
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
          next_state = COMPUTE;
        end
      end
      
      COMPUTE: begin
        if (mem_if.valid) begin
          if (mem_if.error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h10; // Memory error
          end else begin
            fetched_data_d = mem_if.rdata;
            operations_d = operations_q + 1;
            
            // Perform reduction operation
            case (reduce_config.operation)
              OP_SUM: begin
                {overflow_d, accumulator_d} = {1'b0, accumulator_q} + {1'b0, fetched_data_q};
              end
              
              OP_PRODUCT: begin
                // Simple 32-bit multiplication (may overflow)
                accumulator_d = accumulator_q * fetched_data_q;
              end
              
              OP_MIN: begin
                if ($signed(fetched_data_q) < $signed(accumulator_q)) begin
                  accumulator_d = fetched_data_q;
                end
              end
              
              OP_MAX: begin
                if ($signed(fetched_data_q) > $signed(accumulator_q)) begin
                  accumulator_d = fetched_data_q;
                end
              end
              
              OP_AND: begin
                accumulator_d = accumulator_q & fetched_data_q;
              end
              
              OP_OR: begin
                accumulator_d = accumulator_q | fetched_data_q;
              end
              
              OP_XOR: begin
                accumulator_d = accumulator_q ^ fetched_data_q;
              end
              
              default: begin
                next_state = ERROR;
                error_d = 1'b1;
                status_d = 8'h01; // Invalid operation
              end
            endcase
            
            // Check if we've processed all elements
            index_d = index_q + 1;
            if (index_q >= (array_size_q - 1)) begin
              next_state = COMPLETE;
            end else begin
              // Move to next element
              case (reduce_config.data_width)
                3'b000: current_addr_d = current_addr_q + 4; // 32-bit
                3'b001: current_addr_d = current_addr_q + 2; // 16-bit
                3'b010: current_addr_d = current_addr_q + 1; // 8-bit
                default: current_addr_d = current_addr_q + 4;
              endcase
              next_state = FETCH;
            end
          end
        end
      end
      
      COMPLETE: begin
        core_if.valid = 1'b1;
        core_if.result = accumulator_q;
        if (overflow_q) begin
          status_d = 8'h02; // Overflow warning
        end else begin
          status_d = 8'h00; // Success
        end
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
    config_if.unit_status = {4'b0011, current_state, overflow_q}; // Unit ID=3, state, overflow
    config_if.interrupt = (current_state == COMPLETE) || (current_state == ERROR);
  end

endmodule
