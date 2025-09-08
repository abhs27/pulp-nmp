// Copyright 2024 PULPino NMP Implementation Team  
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Top-Level Module                           //
// Complete NMP system with all processing units and controller           //
//////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

module nmp_top (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // Core interface
  input  logic        nmp_req_i,
  output logic        nmp_gnt_o,
  input  logic [31:0] nmp_addr_i,
  input  logic [31:0] nmp_wdata_i,
  output logic [31:0] nmp_rdata_o,
  input  logic        nmp_we_i,
  input  logic [3:0]  nmp_be_i,
  input  logic [2:0]  nmp_op_i,
  input  logic [6:0]  nmp_funct7_i,
  output logic        nmp_valid_o,
  output logic        nmp_ready_o,
  output logic [31:0] nmp_result_o,
  output logic        nmp_error_o,
  output logic [7:0]  nmp_status_o,
  output logic        nmp_busy_o,
  
  // Memory interface  
  output logic        mem_req_o,
  input  logic        mem_gnt_i,
  output logic [31:0] mem_addr_o,
  output logic [31:0] mem_wdata_o,
  input  logic [31:0] mem_rdata_i,
  output logic        mem_we_o,
  output logic [3:0]  mem_be_o,
  input  logic        mem_valid_i,
  input  logic        mem_error_i,
  
  // Configuration interface
  input  logic        nmp_enable_i,
  input  logic        nmp_reset_i,
  output logic [31:0] nmp_perf_counter_o,
  output logic [7:0]  nmp_unit_status_o,
  output logic        nmp_interrupt_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Interface Instances
  //////////////////////////////////////////////////////////////////////////////
  
  // Core interface
  nmp_if core_if();
  
  // Memory interface
  nmp_mem_if mem_if();
  
  // Configuration interface
  nmp_config_if config_if();
  
  // Individual unit interfaces
  nmp_if search_if();
  nmp_if sort_if();
  nmp_if reduce_if();
  nmp_if filter_if();
  nmp_if map_if();
  
  // Individual unit memory interfaces
  nmp_mem_if search_mem_if();
  nmp_mem_if sort_mem_if();
  nmp_mem_if reduce_mem_if();
  nmp_mem_if filter_mem_if();
  nmp_mem_if map_mem_if();
  
  // Individual unit config interfaces
  nmp_config_if search_config_if();
  nmp_config_if sort_config_if();
  nmp_config_if reduce_config_if();
  nmp_config_if filter_config_if();
  nmp_config_if map_config_if();
  
  //////////////////////////////////////////////////////////////////////////////
  // Interface Connections - Core
  //////////////////////////////////////////////////////////////////////////////
  
  // Core interface inputs
  assign core_if.req = nmp_req_i;
  assign core_if.addr = nmp_addr_i;
  assign core_if.wdata = nmp_wdata_i;
  assign core_if.we = nmp_we_i;
  assign core_if.be = nmp_be_i;
  assign core_if.nmp_op = nmp_op_i;
  assign core_if.nmp_funct7 = nmp_funct7_i;
  
  // Core interface outputs
  assign nmp_gnt_o = core_if.gnt;
  assign nmp_valid_o = core_if.valid;
  assign nmp_ready_o = core_if.ready;
  assign nmp_rdata_o = core_if.rdata;
  assign nmp_result_o = core_if.result;
  assign nmp_error_o = core_if.error;
  assign nmp_status_o = core_if.status;
  assign nmp_busy_o = core_if.busy;
  
  //////////////////////////////////////////////////////////////////////////////
  // Interface Connections - Memory
  //////////////////////////////////////////////////////////////////////////////
  
  // Memory interface outputs
  assign mem_req_o = mem_if.req;
  assign mem_addr_o = mem_if.addr;
  assign mem_wdata_o = mem_if.wdata;
  assign mem_we_o = mem_if.we;
  assign mem_be_o = mem_if.be;
  
  // Memory interface inputs
  assign mem_if.gnt = mem_gnt_i;
  assign mem_if.valid = mem_valid_i;
  assign mem_if.rdata = mem_rdata_i;
  assign mem_if.error = mem_error_i;
  assign mem_if.resp = {1'b0, mem_error_i}; // Simple response
  assign mem_if.burst_last = 1'b1; // Single beat transactions for now
  
  //////////////////////////////////////////////////////////////////////////////
  // Interface Connections - Configuration
  //////////////////////////////////////////////////////////////////////////////
  
  // Configuration interface inputs
  assign config_if.enable = nmp_enable_i;
  assign config_if.reset = nmp_reset_i;
  assign config_if.clk_gate_en = 1'b1; // Always enabled for now
  
  // Configuration interface outputs
  assign nmp_perf_counter_o = config_if.perf_counter;
  assign nmp_unit_status_o = config_if.unit_status;
  assign nmp_interrupt_o = config_if.interrupt;
  
  // Unit configuration connections
  assign search_config_if.enable = config_if.enable;
  assign search_config_if.reset = config_if.reset;
  assign search_config_if.clk_gate_en = config_if.clk_gate_en;
  
  assign sort_config_if.enable = config_if.enable;
  assign sort_config_if.reset = config_if.reset;
  assign sort_config_if.clk_gate_en = config_if.clk_gate_en;
  
  assign reduce_config_if.enable = config_if.enable;
  assign reduce_config_if.reset = config_if.reset;
  assign reduce_config_if.clk_gate_en = config_if.clk_gate_en;
  
  assign filter_config_if.enable = config_if.enable;
  assign filter_config_if.reset = config_if.reset;
  assign filter_config_if.clk_gate_en = config_if.clk_gate_en;
  
  assign map_config_if.enable = config_if.enable;
  assign map_config_if.reset = config_if.reset;
  assign map_config_if.clk_gate_en = config_if.clk_gate_en;
  
  //////////////////////////////////////////////////////////////////////////////
  // Memory Arbitration (Simplified Round-Robin)
  //////////////////////////////////////////////////////////////////////////////
  
  logic [2:0] mem_arbiter_state;
  logic [2:0] next_unit_sel;
  logic       any_unit_req;
  
  assign any_unit_req = search_mem_if.req | sort_mem_if.req | reduce_mem_if.req | 
                        filter_mem_if.req | map_mem_if.req;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mem_arbiter_state <= 3'b000;
    end else if (mem_if.req && mem_if.gnt) begin
      mem_arbiter_state <= next_unit_sel;
    end
  end
  
  always_comb begin
    next_unit_sel = mem_arbiter_state;
    
    // Simple round-robin priority
    case (mem_arbiter_state)
      3'b000: if (sort_mem_if.req)    next_unit_sel = 3'b001;
              else if (reduce_mem_if.req)  next_unit_sel = 3'b010;
              else if (filter_mem_if.req)  next_unit_sel = 3'b011;
              else if (map_mem_if.req)     next_unit_sel = 3'b100;
              else if (search_mem_if.req)  next_unit_sel = 3'b000;
              
      3'b001: if (reduce_mem_if.req)  next_unit_sel = 3'b010;
              else if (filter_mem_if.req)  next_unit_sel = 3'b011;
              else if (map_mem_if.req)     next_unit_sel = 3'b100;
              else if (search_mem_if.req)  next_unit_sel = 3'b000;
              else if (sort_mem_if.req)    next_unit_sel = 3'b001;
              
      3'b010: if (filter_mem_if.req)  next_unit_sel = 3'b011;
              else if (map_mem_if.req)     next_unit_sel = 3'b100;
              else if (search_mem_if.req)  next_unit_sel = 3'b000;
              else if (sort_mem_if.req)    next_unit_sel = 3'b001;
              else if (reduce_mem_if.req)  next_unit_sel = 3'b010;
              
      3'b011: if (map_mem_if.req)     next_unit_sel = 3'b100;
              else if (search_mem_if.req)  next_unit_sel = 3'b000;
              else if (sort_mem_if.req)    next_unit_sel = 3'b001;
              else if (reduce_mem_if.req)  next_unit_sel = 3'b010;
              else if (filter_mem_if.req)  next_unit_sel = 3'b011;
              
      3'b100: if (search_mem_if.req)  next_unit_sel = 3'b000;
              else if (sort_mem_if.req)    next_unit_sel = 3'b001;
              else if (reduce_mem_if.req)  next_unit_sel = 3'b010;
              else if (filter_mem_if.req)  next_unit_sel = 3'b011;
              else if (map_mem_if.req)     next_unit_sel = 3'b100;
              
      default: next_unit_sel = 3'b000;
    endcase
  end
  
  // Memory interface multiplexing
  always_comb begin
    // Default assignments
    mem_if.req = 1'b0;
    mem_if.addr = 32'h0;
    mem_if.wdata = 32'h0;
    mem_if.we = 1'b0;
    mem_if.be = 4'b0000;
    mem_if.id = 8'h00;
    mem_if.burst = 1'b0;
    mem_if.burst_len = 4'h1;
    
    // Grant signals (only selected unit gets grant)
    search_mem_if.gnt = 1'b0;
    sort_mem_if.gnt = 1'b0;
    reduce_mem_if.gnt = 1'b0;
    filter_mem_if.gnt = 1'b0;
    map_mem_if.gnt = 1'b0;
    
    // Valid and data signals (broadcast to all units)
    search_mem_if.valid = mem_if.valid;
    search_mem_if.rdata = mem_if.rdata;
    search_mem_if.error = mem_if.error;
    search_mem_if.resp = mem_if.resp;
    search_mem_if.burst_last = mem_if.burst_last;
    
    sort_mem_if.valid = mem_if.valid;
    sort_mem_if.rdata = mem_if.rdata;
    sort_mem_if.error = mem_if.error;
    sort_mem_if.resp = mem_if.resp;
    sort_mem_if.burst_last = mem_if.burst_last;
    
    reduce_mem_if.valid = mem_if.valid;
    reduce_mem_if.rdata = mem_if.rdata;
    reduce_mem_if.error = mem_if.error;
    reduce_mem_if.resp = mem_if.resp;
    reduce_mem_if.burst_last = mem_if.burst_last;
    
    filter_mem_if.valid = mem_if.valid;
    filter_mem_if.rdata = mem_if.rdata;
    filter_mem_if.error = mem_if.error;
    filter_mem_if.resp = mem_if.resp;
    filter_mem_if.burst_last = mem_if.burst_last;
    
    map_mem_if.valid = mem_if.valid;
    map_mem_if.rdata = mem_if.rdata;
    map_mem_if.error = mem_if.error;
    map_mem_if.resp = mem_if.resp;
    map_mem_if.burst_last = mem_if.burst_last;
    
    // Select active unit based on arbiter
    case (mem_arbiter_state)
      3'b000: if (search_mem_if.req) begin
        mem_if.req = search_mem_if.req;
        mem_if.addr = search_mem_if.addr;
        mem_if.wdata = search_mem_if.wdata;
        mem_if.we = search_mem_if.we;
        mem_if.be = search_mem_if.be;
        mem_if.id = search_mem_if.id;
        search_mem_if.gnt = mem_if.gnt;
      end
      
      3'b001: if (sort_mem_if.req) begin
        mem_if.req = sort_mem_if.req;
        mem_if.addr = sort_mem_if.addr;
        mem_if.wdata = sort_mem_if.wdata;
        mem_if.we = sort_mem_if.we;
        mem_if.be = sort_mem_if.be;
        mem_if.id = sort_mem_if.id;
        sort_mem_if.gnt = mem_if.gnt;
      end
      
      3'b010: if (reduce_mem_if.req) begin
        mem_if.req = reduce_mem_if.req;
        mem_if.addr = reduce_mem_if.addr;
        mem_if.wdata = reduce_mem_if.wdata;
        mem_if.we = reduce_mem_if.we;
        mem_if.be = reduce_mem_if.be;
        mem_if.id = reduce_mem_if.id;
        reduce_mem_if.gnt = mem_if.gnt;
      end
      
      3'b011: if (filter_mem_if.req) begin
        mem_if.req = filter_mem_if.req;
        mem_if.addr = filter_mem_if.addr;
        mem_if.wdata = filter_mem_if.wdata;
        mem_if.we = filter_mem_if.we;
        mem_if.be = filter_mem_if.be;
        mem_if.id = filter_mem_if.id;
        filter_mem_if.gnt = mem_if.gnt;
      end
      
      3'b100: if (map_mem_if.req) begin
        mem_if.req = map_mem_if.req;
        mem_if.addr = map_mem_if.addr;
        mem_if.wdata = map_mem_if.wdata;
        mem_if.we = map_mem_if.we;
        mem_if.be = map_mem_if.be;
        mem_if.id = map_mem_if.id;
        map_mem_if.gnt = mem_if.gnt;
      end
    endcase
  end
  
  //////////////////////////////////////////////////////////////////////////////
  // Module Instantiations
  //////////////////////////////////////////////////////////////////////////////
  
  // NMP Controller
  nmp_controller nmp_controller_i (
    .clk_i      ( clk_i     ),
    .rst_ni     ( rst_ni    ),
    .core_if    ( core_if   ),
    .mem_if     ( mem_if    ),
    .config_if  ( config_if ),
    .search_if  ( search_if ),
    .sort_if    ( sort_if   ),
    .reduce_if  ( reduce_if ),
    .filter_if  ( filter_if ),
    .map_if     ( map_if    )
  );
  
  // Search Unit
  nmp_search_unit nmp_search_unit_i (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .core_if    ( search_if         ),
    .mem_if     ( search_mem_if     ),
    .config_if  ( search_config_if  )
  );
  
  // Sort Unit  
  nmp_sort_unit nmp_sort_unit_i (
    .clk_i      ( clk_i           ),
    .rst_ni     ( rst_ni          ),
    .core_if    ( sort_if         ),
    .mem_if     ( sort_mem_if     ),
    .config_if  ( sort_config_if  )
  );
  
  // Reduce Unit
  nmp_reduce_unit nmp_reduce_unit_i (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .core_if    ( reduce_if         ),
    .mem_if     ( reduce_mem_if     ),
    .config_if  ( reduce_config_if  )
  );
  
  // Filter Unit
  nmp_filter_unit nmp_filter_unit_i (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .core_if    ( filter_if         ),
    .mem_if     ( filter_mem_if     ),
    .config_if  ( filter_config_if  )
  );
  
  // Map Unit
  nmp_map_unit nmp_map_unit_i (
    .clk_i      ( clk_i          ),
    .rst_ni     ( rst_ni         ),
    .core_if    ( map_if         ),
    .mem_if     ( map_mem_if     ),
    .config_if  ( map_config_if  )
  );

endmodule
