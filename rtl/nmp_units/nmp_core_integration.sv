//////////////////////////////////////////////////////////////////////////////
// NMP Integration into PULPino Core Region
// This file contains the necessary modifications to integrate NMP units
// with the PULPino data memory system
//////////////////////////////////////////////////////////////////////////////

// Additional signals for NMP integration (to be added to core_region.sv)

  // NMP interface signals  
  logic         nmp_data_req;
  logic         nmp_data_gnt; 
  logic         nmp_data_rvalid;
  logic [31:0]  nmp_data_addr;
  logic         nmp_data_we;
  logic [3:0]   nmp_data_be;
  logic [31:0]  nmp_data_rdata;
  logic [31:0]  nmp_data_wdata;
  logic         nmp_data_error;
  
  // NMP control signals
  logic         nmp_req;
  logic         nmp_gnt;
  logic [31:0]  nmp_nmp_addr;
  logic [31:0]  nmp_nmp_wdata;
  logic [31:0]  nmp_nmp_rdata;
  logic         nmp_we;
  logic [3:0]   nmp_be;
  logic [2:0]   nmp_op;
  logic [6:0]   nmp_funct7;
  logic         nmp_valid;
  logic         nmp_ready;
  logic [31:0]  nmp_result;
  logic         nmp_error;
  logic [7:0]   nmp_status;
  logic         nmp_busy;

//////////////////////////////////////////////////////////////////////////////
// NMP Data Memory Arbiter (3-way arbitration)
// Priority: AXI > Core > NMP  
//////////////////////////////////////////////////////////////////////////////

typedef enum logic [1:0] {
  ARB_AXI  = 2'b00,
  ARB_CORE = 2'b01, 
  ARB_NMP  = 2'b10
} mem_arb_state_t;

mem_arb_state_t mem_arb_state, mem_arb_next;
logic mem_arb_req, mem_arb_gnt, mem_arb_rvalid;
logic [DATA_ADDR_WIDTH-1:0] mem_arb_addr;
logic mem_arb_we;
logic [3:0] mem_arb_be;
logic [31:0] mem_arb_rdata, mem_arb_wdata;

// Memory arbiter state machine
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    mem_arb_state <= ARB_AXI;
  end else begin
    mem_arb_state <= mem_arb_next;
  end
end

// Arbitration logic (priority-based with round-robin between core and NMP)
always_comb begin
  mem_arb_next = mem_arb_state;
  
  // Default assignments
  mem_arb_req = 1'b0;
  mem_arb_addr = '0;
  mem_arb_we = 1'b0;
  mem_arb_be = 4'b0000;
  mem_arb_wdata = 32'h0;
  
  // Grant assignments
  core_data_gnt = 1'b0;
  nmp_data_gnt = 1'b0;
  
  // AXI has highest priority (always gets access if requesting)
  if (axi_mem_req) begin
    mem_arb_req = axi_mem_req;
    mem_arb_addr = axi_mem_addr[DATA_ADDR_WIDTH-AXI_B_WIDTH-1:0];
    mem_arb_we = axi_mem_we;
    mem_arb_be = axi_mem_be[3:0]; // Truncate to 4 bits
    mem_arb_wdata = axi_mem_wdata[31:0]; // Truncate to 32 bits
    mem_arb_next = ARB_AXI;
  end
  // Round-robin between Core and NMP when AXI not requesting
  else begin
    case (mem_arb_state)
      ARB_AXI, ARB_CORE: begin
        if (nmp_data_req) begin
          mem_arb_req = nmp_data_req;
          mem_arb_addr = nmp_data_addr[DATA_ADDR_WIDTH-1:0];
          mem_arb_we = nmp_data_we;
          mem_arb_be = nmp_data_be;
          mem_arb_wdata = nmp_data_wdata;
          nmp_data_gnt = mem_arb_gnt;
          mem_arb_next = ARB_NMP;
        end else if (core_data_req) begin
          mem_arb_req = core_data_req;
          mem_arb_addr = core_data_addr[DATA_ADDR_WIDTH-1:0];
          mem_arb_we = core_data_we;
          mem_arb_be = core_data_be;
          mem_arb_wdata = core_data_wdata;
          core_data_gnt = mem_arb_gnt;
          mem_arb_next = ARB_CORE;
        end
      end
      
      ARB_NMP: begin
        if (core_data_req) begin
          mem_arb_req = core_data_req;
          mem_arb_addr = core_data_addr[DATA_ADDR_WIDTH-1:0];
          mem_arb_we = core_data_we;
          mem_arb_be = core_data_be;
          mem_arb_wdata = core_data_wdata;
          core_data_gnt = mem_arb_gnt;
          mem_arb_next = ARB_CORE;
        end else if (nmp_data_req) begin
          mem_arb_req = nmp_data_req;
          mem_arb_addr = nmp_data_addr[DATA_ADDR_WIDTH-1:0];
          mem_arb_we = nmp_data_we;
          mem_arb_be = nmp_data_be;
          mem_arb_wdata = nmp_data_wdata;
          nmp_data_gnt = mem_arb_gnt;
          mem_arb_next = ARB_NMP;
        end
      end
    endcase
  end
end

// Response routing
always_comb begin
  // Default assignments
  core_data_rdata = 32'h0;
  core_data_rvalid = 1'b0;
  nmp_data_rdata = 32'h0;
  nmp_data_rvalid = 1'b0;
  axi_mem_rdata = '0;
  
  case (mem_arb_state)
    ARB_AXI: begin
      axi_mem_rdata = {{(AXI_DATA_WIDTH-32){1'b0}}, mem_arb_rdata};
    end
    ARB_CORE: begin
      core_data_rdata = mem_arb_rdata;
      core_data_rvalid = mem_arb_rvalid;
    end
    ARB_NMP: begin
      nmp_data_rdata = mem_arb_rdata;
      nmp_data_rvalid = mem_arb_rvalid;
      nmp_data_error = 1'b0; // Simplified error handling
    end
  endcase
end
