// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Memory Interface                           //
// This interface defines the memory access protocol for NMP units         //
//////////////////////////////////////////////////////////////////////////////

interface nmp_mem_if;
  // Memory request signals
  logic        req;         // Memory request
  logic        gnt;         // Memory grant
  logic        valid;       // Memory response valid
  
  // Address and data
  logic [31:0] addr;        // Memory address
  logic [31:0] wdata;       // Write data
  logic [31:0] rdata;       // Read data
  
  // Control signals
  logic        we;          // Write enable
  logic [3:0]  be;          // Byte enable
  logic [7:0]  id;          // Transaction ID
  
  // Burst support
  logic        burst;       // Burst transaction
  logic [3:0]  burst_len;   // Burst length (1, 4, 8, 16)
  logic        burst_last;  // Last beat in burst
  
  // Error and status
  logic        error;       // Memory error
  logic [1:0]  resp;        // Response status (OK, ERROR, RETRY)

  // NMP unit-side modport (from NMP unit perspective)
  modport nmp_unit (
    output req, addr, wdata, we, be, id, burst, burst_len,
    input  gnt, valid, rdata, burst_last, error, resp
  );
  
  // Memory controller-side modport (from memory controller perspective)
  modport mem_ctrl (
    input  req, addr, wdata, we, be, id, burst, burst_len,
    output gnt, valid, rdata, burst_last, error, resp
  );

endinterface

//////////////////////////////////////////////////////////////////////////////
// NMP Configuration Interface                                              //
// This interface defines configuration and control signals for NMP units  //
//////////////////////////////////////////////////////////////////////////////

interface nmp_config_if;
  // Configuration registers
  logic [31:0] config_data; // Configuration data
  logic [7:0]  config_addr; // Configuration address
  logic        config_we;   // Configuration write enable
  logic        config_re;   // Configuration read enable
  logic [31:0] config_rdata;// Configuration read data
  
  // Control signals
  logic        enable;      // Unit enable
  logic        reset;       // Unit reset
  logic        clk_gate_en; // Clock gating enable
  
  // Status reporting
  logic [31:0] perf_counter;// Performance counter
  logic [7:0]  unit_status; // Unit status
  logic        interrupt;   // Interrupt request

  // Core-side modport (from processor core perspective)
  modport core (
    output config_data, config_addr, config_we, config_re, enable, reset, clk_gate_en,
    input  config_rdata, perf_counter, unit_status, interrupt
  );
  
  // NMP unit-side modport (from NMP unit perspective)
  modport nmp_unit (
    input  config_data, config_addr, config_we, config_re, enable, reset, clk_gate_en,
    output config_rdata, perf_counter, unit_status, interrupt
  );

endinterface
