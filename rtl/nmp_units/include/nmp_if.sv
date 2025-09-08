// Copyright 2024 PULPino NMP Implementation Team
// Licensed under the Solderpad Hardware License v0.51

//////////////////////////////////////////////////////////////////////////////
// Near Memory Processing (NMP) Core Interface                             //
// This interface defines the communication protocol between the processor  //
// core and NMP units                                                       //
//////////////////////////////////////////////////////////////////////////////

interface nmp_if;
  // Control signals
  logic        req;         // Request signal from core to NMP
  logic        gnt;         // Grant signal from NMP to core
  logic        valid;       // Response valid from NMP to core
  logic        ready;       // Unit ready for new operation
  
  // Address and data
  logic [31:0] addr;        // Memory address for NMP operation
  logic [31:0] wdata;       // Write data to NMP unit
  logic [31:0] rdata;       // Read data from NMP unit
  logic [31:0] result;      // Operation result
  
  // Control
  logic        we;          // Write enable
  logic [3:0]  be;          // Byte enable
  logic [2:0]  nmp_op;      // NMP operation type (funct3)
  logic [6:0]  nmp_funct7;  // Additional operation encoding (funct7)
  
  // Status and error reporting
  logic        error;       // Error flag
  logic [7:0]  status;      // Detailed status information
  
  // Performance monitoring
  logic [31:0] cycle_count; // Operation cycle count
  logic        busy;        // Unit busy flag

  // Core-side modport (from processor core perspective)
  modport core (
    output req, addr, wdata, we, be, nmp_op, nmp_funct7,
    input  gnt, valid, rdata, result, ready, error, status, cycle_count, busy
  );
  
  // NMP unit-side modport (from NMP unit perspective)  
  modport nmp_unit (
    input  req, addr, wdata, we, be, nmp_op, nmp_funct7,
    output gnt, valid, rdata, result, ready, error, status, cycle_count, busy
  );

endinterface
