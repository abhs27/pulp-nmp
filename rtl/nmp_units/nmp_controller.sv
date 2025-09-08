// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Controller                                 //
// Main controller that dispatches NMP operations to appropriate units     //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_controller (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  nmp_if.nmp_unit     core_if,
  
  // Memory interface  
  nmp_mem_if.nmp_unit mem_if,
  
  // Configuration interface
  nmp_config_if.nmp_unit config_if,
  
  // Individual NMP unit interfaces
  nmp_if.core         search_if,
  nmp_if.core         sort_if,
  nmp_if.core         reduce_if,
  nmp_if.core         filter_if,
  nmp_if.core         map_if
);

  // Internal state machine
  typedef enum logic [2:0] {
    IDLE,
    DECODE,
    DISPATCH,
    WAIT_RESPONSE,
    COMPLETE,
    ERROR
  } nmp_state_t;
  
  nmp_state_t current_state, next_state;
  
  // Internal registers
  logic [2:0]  operation_q, operation_d;
  logic [6:0]  funct7_q, funct7_d;
  logic [31:0] addr_q, addr_d;
  logic [31:0] data_q, data_d;
  logic [31:0] result_q, result_d;
  logic        error_q, error_d;
  logic [7:0]  status_q, status_d;
  logic [31:0] cycle_count_q, cycle_count_d;
  
  // Unit selection signals
  logic        select_search, select_sort, select_reduce, select_filter, select_map;
  logic        unit_req, unit_gnt, unit_valid, unit_ready, unit_error;
  logic [31:0] unit_result;
  logic [7:0]  unit_status;
  
  //////////////////////////////////////////////////////////////////////////////
  // State Machine
  //////////////////////////////////////////////////////////////////////////////
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state  <= IDLE;
      operation_q    <= 3'b000;
      funct7_q       <= 7'b0000000;
      addr_q         <= 32'h0;
      data_q         <= 32'h0;
      result_q       <= 32'h0;
      error_q        <= 1'b0;
      status_q       <= 8'h00;
      cycle_count_q  <= 32'h0;
    end else begin
      current_state  <= next_state;
      operation_q    <= operation_d;
      funct7_q       <= funct7_d;
      addr_q         <= addr_d;
      data_q         <= data_d;
      result_q       <= result_d;
      error_q        <= error_d;
      status_q       <= status_d;
      cycle_count_q  <= cycle_count_d;
    end
  end
  
  always_comb begin
    // Default assignments
    next_state    = current_state;
    operation_d   = operation_q;
    funct7_d      = funct7_q;
    addr_d        = addr_q;
    data_d        = data_q;
    result_d      = result_q;
    error_d       = error_q;
    status_d      = status_q;
    cycle_count_d = cycle_count_q;
    
    // Default outputs to core
    core_if.gnt    = 1'b0;
    core_if.valid  = 1'b0;
    core_if.ready  = 1'b1;
    core_if.rdata  = 32'h0;
    core_if.result = result_q;
    core_if.error  = error_q;
    core_if.status = status_q;
    core_if.cycle_count = cycle_count_q;
    core_if.busy   = (current_state != IDLE);
    
    case (current_state)
      IDLE: begin
        core_if.ready = 1'b1;
        if (core_if.req && config_if.enable) begin
          next_state = DECODE;
          core_if.gnt = 1'b1;
          operation_d = core_if.nmp_op;
          funct7_d    = core_if.nmp_funct7;
          addr_d      = core_if.addr;
          data_d      = core_if.wdata;
          cycle_count_d = 32'h1;
        end
      end
      
      DECODE: begin
        // Validate operation type
        case (operation_q)
          NMP_SEARCH, NMP_SORT, NMP_REDUCE, NMP_FILTER, NMP_MAP: begin
            next_state = DISPATCH;
          end
          default: begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = 8'h01; // Invalid operation
          end
        endcase
        cycle_count_d = cycle_count_q + 1;
      end
      
      DISPATCH: begin
        // Dispatch to appropriate unit
        next_state = WAIT_RESPONSE;
        cycle_count_d = cycle_count_q + 1;
      end
      
      WAIT_RESPONSE: begin
        cycle_count_d = cycle_count_q + 1;
        if (unit_valid) begin
          if (unit_error) begin
            next_state = ERROR;
            error_d = 1'b1;
            status_d = unit_status;
          end else begin
            next_state = COMPLETE;
            result_d = unit_result;
            error_d = 1'b0;
            status_d = 8'h00; // Success
          end
        end
      end
      
      COMPLETE: begin
        core_if.valid = 1'b1;
        core_if.result = result_q;
        next_state = IDLE;
        cycle_count_d = cycle_count_q + 1;
      end
      
      ERROR: begin
        core_if.valid = 1'b1;
        core_if.error = 1'b1;
        core_if.status = status_q;
        next_state = IDLE;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Unit Selection Logic
  //////////////////////////////////////////////////////////////////////////////
  
  always_comb begin
    select_search  = (operation_q == NMP_SEARCH);
    select_sort    = (operation_q == NMP_SORT);
    select_reduce  = (operation_q == NMP_REDUCE);
    select_filter  = (operation_q == NMP_FILTER);
    select_map     = (operation_q == NMP_MAP);
    
    // Request to selected unit
    unit_req = (current_state == DISPATCH);
    
    // Aggregate responses from units
    unit_gnt = (select_search  && search_if.gnt) ||
               (select_sort    && sort_if.gnt) ||
               (select_reduce  && reduce_if.gnt) ||
               (select_filter  && filter_if.gnt) ||
               (select_map     && map_if.gnt);
               
    unit_valid = (select_search  && search_if.valid) ||
                 (select_sort    && sort_if.valid) ||
                 (select_reduce  && reduce_if.valid) ||
                 (select_filter  && filter_if.valid) ||
                 (select_map     && map_if.valid);
                 
    unit_ready = (select_search  && search_if.ready) ||
                 (select_sort    && sort_if.ready) ||
                 (select_reduce  && reduce_if.ready) ||
                 (select_filter  && filter_if.ready) ||
                 (select_map     && map_if.ready);
                 
    unit_error = (select_search  && search_if.error) ||
                 (select_sort    && sort_if.error) ||
                 (select_reduce  && reduce_if.error) ||
                 (select_filter  && filter_if.error) ||
                 (select_map     && map_if.error);
    
    // Result multiplexing
    case (operation_q)
      NMP_SEARCH:  begin
        unit_result = search_if.result;
        unit_status = search_if.status;
      end
      NMP_SORT:    begin
        unit_result = sort_if.result;
        unit_status = sort_if.status;
      end
      NMP_REDUCE:  begin
        unit_result = reduce_if.result;
        unit_status = reduce_if.status;
      end
      NMP_FILTER:  begin
        unit_result = filter_if.result;
        unit_status = filter_if.status;
      end
      NMP_MAP:     begin
        unit_result = map_if.result;
        unit_status = map_if.status;
      end
      default: begin
        unit_result = 32'h0;
        unit_status = 8'hFF;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Unit Interface Connections
  //////////////////////////////////////////////////////////////////////////////
  
  // Search unit
  assign search_if.req       = unit_req && select_search;
  assign search_if.addr      = addr_q;
  assign search_if.wdata     = data_q;
  assign search_if.we        = core_if.we;
  assign search_if.be        = core_if.be;
  assign search_if.nmp_op    = operation_q;
  assign search_if.nmp_funct7 = funct7_q;
  
  // Sort unit
  assign sort_if.req         = unit_req && select_sort;
  assign sort_if.addr        = addr_q;
  assign sort_if.wdata       = data_q;
  assign sort_if.we          = core_if.we;
  assign sort_if.be          = core_if.be;
  assign sort_if.nmp_op      = operation_q;
  assign sort_if.nmp_funct7  = funct7_q;
  
  // Reduce unit
  assign reduce_if.req       = unit_req && select_reduce;
  assign reduce_if.addr      = addr_q;
  assign reduce_if.wdata     = data_q;
  assign reduce_if.we        = core_if.we;
  assign reduce_if.be        = core_if.be;
  assign reduce_if.nmp_op    = operation_q;
  assign reduce_if.nmp_funct7 = funct7_q;
  
  // Filter unit
  assign filter_if.req       = unit_req && select_filter;
  assign filter_if.addr      = addr_q;
  assign filter_if.wdata     = data_q;
  assign filter_if.we        = core_if.we;
  assign filter_if.be        = core_if.be;
  assign filter_if.nmp_op    = operation_q;
  assign filter_if.nmp_funct7 = funct7_q;
  
  // Map unit
  assign map_if.req          = unit_req && select_map;
  assign map_if.addr         = addr_q;
  assign map_if.wdata        = data_q;
  assign map_if.we           = core_if.we;
  assign map_if.be           = core_if.be;
  assign map_if.nmp_op       = operation_q;
  assign map_if.nmp_funct7   = funct7_q;
  
  //////////////////////////////////////////////////////////////////////////////
  // Performance Monitoring
  //////////////////////////////////////////////////////////////////////////////
  
  // Performance counter update
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      config_if.perf_counter <= 32'h0;
    end else if (current_state == COMPLETE) begin
      config_if.perf_counter <= config_if.perf_counter + cycle_count_q;
    end
  end
  
  // Status reporting
  assign config_if.unit_status = {5'b00000, current_state};
  assign config_if.interrupt   = (current_state == ERROR);

endmodule
