//-----------------------------------------------------------------------------
// Title         : NMP Address Generation Unit (Corrected)
// Project       : PULPino NMP Extension
// Description   : Generates addresses for array access operations
//-----------------------------------------------------------------------------

module nmp_addr_gen #(
    parameter [31:0] RS1_BASE_PTR_ADDR = 32'h00100000,
    parameter [31:0] RS2_BASE_PTR_ADDR = 32'h00100004,
    parameter [31:0] RD_BASE_PTR_ADDR  = 32'h00100008
) (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Control Interface
    input  wire [1:0]  addr_load_counter,
    input  wire [4:0]  element_counter,

    // Base address inputs
    input  wire [31:0] rs1_base_addr,
    input  wire [31:0] rs2_base_addr,
    input  wire [31:0] rd_base_addr,

    // Address Outputs
    output wire [31:0] base_ptr_addr,
    output wire [31:0] rs1_element_addr,
    output wire [31:0] rs2_element_addr,
    output wire [31:0] rd_element_addr
);

    // Base pointer address generation (for loading base addresses)
    assign base_ptr_addr = (addr_load_counter == 2'd0) ? RS1_BASE_PTR_ADDR :
                          (addr_load_counter == 2'd1) ? RS2_BASE_PTR_ADDR :
                          (addr_load_counter == 2'd2) ? RD_BASE_PTR_ADDR  : 32'h0;

    // Element address generation (base + element_counter * 4)
    assign rs1_element_addr = rs1_base_addr + (element_counter << 2);
    assign rs2_element_addr = rs2_base_addr + (element_counter << 2);
    assign rd_element_addr  = rd_base_addr  + (element_counter << 2);

endmodule
