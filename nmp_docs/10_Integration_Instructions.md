# NMP Integration with PULPino Core - CRITICAL ARCHITECTURE FIX

## ISSUE IDENTIFIED
The current NMP implementation is NOT integrated with the PULPino core memory system. 
This violates the requirement that NMP should use the same data_memory as the PULPino processor.

## REQUIRED CHANGES TO CORE_REGION.SV

### 1. Add NMP Module Port (after line 48 - tdo_o port):
  // NMP interface ports
  input  logic        nmp_enable_i,
  output logic        nmp_req_o,
  input  logic        nmp_gnt_i,
  output logic [31:0] nmp_addr_o,
  output logic [31:0] nmp_wdata_o,
  input  logic [31:0] nmp_rdata_i,
  output logic        nmp_we_o,
  output logic [3:0]  nmp_be_o,
  output logic [2:0]  nmp_op_o,
  output logic [6:0]  nmp_funct7_o,
  input  logic        nmp_valid_i,
  output logic        nmp_ready_o,
  input  logic [31:0] nmp_result_i,
  input  logic        nmp_error_i,
  input  logic [7:0]  nmp_status_i,
  input  logic        nmp_busy_i

### 2. Include NMP Integration Logic (after line 90 - after AXI signals):
`include "nmp_units/nmp_core_integration.sv"

### 3. Add NMP Unit Instantiation (after line 720 - before endmodule):
  // NMP Units Integration
  nmp_top nmp_top_i (
    .clk_i          ( clk                ),
    .rst_ni         ( rst_n              ),
    .nmp_req_i      ( nmp_req            ),
    .nmp_gnt_o      ( nmp_gnt            ),
    .nmp_addr_i     ( nmp_nmp_addr       ),
    .nmp_wdata_i    ( nmp_nmp_wdata      ),
    .nmp_rdata_o    ( nmp_nmp_rdata      ),
    .nmp_we_i       ( nmp_we             ),
    .nmp_be_i       ( nmp_be             ),
    .nmp_op_i       ( nmp_op             ),
    .nmp_funct7_i   ( nmp_funct7         ),
    .nmp_valid_o    ( nmp_valid          ),
    .nmp_ready_o    ( nmp_ready          ),
    .nmp_result_o   ( nmp_result         ),
    .nmp_error_o    ( nmp_error          ),
    .nmp_status_o   ( nmp_status         ),
    .nmp_busy_o     ( nmp_busy           ),
    .mem_req_o      ( nmp_data_req       ),
    .mem_gnt_i      ( nmp_data_gnt       ),
    .mem_addr_o     ( nmp_data_addr      ),
    .mem_wdata_o    ( nmp_data_wdata     ),
    .mem_rdata_i    ( nmp_data_rdata     ),
    .mem_we_o       ( nmp_data_we        ),
    .mem_be_o       ( nmp_data_be        ),
    .mem_valid_i    ( nmp_data_rvalid    ),
    .mem_error_i    ( nmp_data_error     ),
    .nmp_enable_i   ( nmp_enable_i       ),
    .nmp_reset_i    ( ~rst_n             ),
    .nmp_perf_counter_o   (              ),
    .nmp_unit_status_o    (              ),
    .nmp_interrupt_o      (              )
  );

### 4. Replace data_ram_mux_i instantiation (around line 526):
Replace the current 2-port data_ram_mux_i with the new 3-way arbiter:

  // Connect arbiter to actual memory
  assign mem_arb_gnt = 1'b1; // Simplified - memory always grants
  assign mem_arb_rvalid = 1'b1; // Simplified - data always valid next cycle
  
  // Use single-port memory interface
  sp_ram
  #(
    .ADDR_WIDTH ( DATA_ADDR_WIDTH ),
    .DATA_WIDTH ( 32 ),
    .NUM_WORDS  ( 2**DATA_ADDR_WIDTH )
  )
  data_mem_i
  (
    .clk      ( clk           ),
    .rst_n    ( rst_n         ),
    .en_i     ( mem_arb_req   ),
    .addr_i   ( mem_arb_addr  ),
    .wdata_i  ( mem_arb_wdata ),
    .rdata_o  ( mem_arb_rdata ),
    .we_i     ( mem_arb_we    ),
    .be_i     ( mem_arb_be    )
  );

## CRITICAL IMPORTANCE
This integration is ESSENTIAL for the NMP to work correctly with PULPino's memory system.
Without this, NMP units will not have access to the same data memory as the processor core,
violating the fundamental architectural requirement.
