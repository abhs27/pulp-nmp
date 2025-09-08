// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Controller FSM                             //
// Finite State Machine for NMP operation control and sequencing          //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_controller_fsm (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Control inputs
  input  logic        start_i,        // Start operation
  input  logic        enable_i,       // NMP enable
  input  logic [2:0]  operation_i,    // NMP operation type
  
  // Unit status inputs
  input  logic        unit_ready_i,   // Selected unit ready
  input  logic        unit_valid_i,   // Unit response valid
  input  logic        unit_error_i,   // Unit error
  
  // Memory interface status
  input  logic        mem_gnt_i,      // Memory grant
  input  logic        mem_valid_i,    // Memory response valid
  input  logic        mem_error_i,    // Memory error
  
  // Control outputs
  output logic        gnt_o,          // Grant to core
  output logic        valid_o,        // Valid response to core
  output logic        ready_o,        // Ready for new operation
  output logic        unit_req_o,     // Request to selected unit
  output logic        mem_req_o,      // Memory request
  output logic        error_o,        // Error flag
  output logic [7:0]  status_o,       // Status code
  
  // State outputs for debugging
  output logic [2:0]  state_o         // Current state
);

  // State encoding
  typedef enum logic [2:0] {
    ST_IDLE       = 3'b000,
    ST_DECODE     = 3'b001,
    ST_DISPATCH   = 3'b010,
    ST_WAIT_UNIT  = 3'b011,
    ST_COMPLETE   = 3'b100,
    ST_ERROR      = 3'b101
  } state_t;
  
  state_t current_state, next_state;
  
  // Internal registers
  logic [2:0] operation_reg;
  logic [7:0] error_code;
  
  //////////////////////////////////////////////////////////////////////////////
  // State Register
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state <= ST_IDLE;
      operation_reg <= 3'b000;
      error_code    <= 8'h00;
    end else begin
      current_state <= next_state;
      if (start_i && current_state == ST_IDLE) begin
        operation_reg <= operation_i;
      end
    end
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Next State Logic
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      ST_IDLE: begin
        if (start_i && enable_i) begin
          next_state = ST_DECODE;
        end
      end
      
      ST_DECODE: begin
        // Validate operation
        case (operation_reg)
          NMP_SEARCH, NMP_SORT, NMP_REDUCE, NMP_FILTER, NMP_MAP: begin
            next_state = ST_DISPATCH;
          end
          default: begin
            next_state = ST_ERROR;
          end
        endcase
      end
      
      ST_DISPATCH: begin
        if (unit_ready_i) begin
          next_state = ST_WAIT_UNIT;
        end
      end
      
      ST_WAIT_UNIT: begin
        if (unit_valid_i) begin
          if (unit_error_i) begin
            next_state = ST_ERROR;
          end else begin
            next_state = ST_COMPLETE;
          end
        end
      end
      
      ST_COMPLETE: begin
        next_state = ST_IDLE;
      end
      
      ST_ERROR: begin
        next_state = ST_IDLE;
      end
      
      default: begin
        next_state = ST_IDLE;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Output Logic
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    // Default outputs
    gnt_o      = 1'b0;
    valid_o    = 1'b0;
    ready_o    = 1'b0;
    unit_req_o = 1'b0;
    mem_req_o  = 1'b0;
    error_o    = 1'b0;
    status_o   = 8'h00;
    state_o    = current_state;
    
    case (current_state)
      ST_IDLE: begin
        ready_o = 1'b1;
        if (start_i && enable_i) begin
          gnt_o = 1'b1;
        end
      end
      
      ST_DECODE: begin
        // Validation in progress
      end
      
      ST_DISPATCH: begin
        unit_req_o = 1'b1;
      end
      
      ST_WAIT_UNIT: begin
        // Waiting for unit completion
      end
      
      ST_COMPLETE: begin
        valid_o  = 1'b1;
        status_o = 8'h00; // Success
      end
      
      ST_ERROR: begin
        valid_o = 1'b1;
        error_o = 1'b1;
        // Set error status based on error type
        case (operation_reg)
          default: status_o = 8'h01; // Invalid operation
        endcase
        if (unit_error_i) begin
          status_o = 8'h02; // Unit error
        end
        if (mem_error_i) begin
          status_o = 8'h03; // Memory error
        end
      end
    endcase
  end

endmodule
