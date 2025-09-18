//-----------------------------------------------------------------------------
// Title         : NMP AXI4-Lite Master Interface (Fixed)
// Project       : PULPino NMP Extension
// Description   : AXI4-Lite master interface for NMP memory operations
//-----------------------------------------------------------------------------

module nmp_axi_master (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control Interface
    input  wire [2:0]  current_state,
    input  wire        start_addr_load,
    input  wire        start_element_read,
    input  wire        start_element_write,
    input  wire [1:0]  addr_load_counter,
    
    // Address inputs
    input  wire [31:0] base_ptr_addr,
    input  wire [31:0] rs1_element_addr,
    input  wire [31:0] rs2_element_addr,
    input  wire [31:0] rd_element_addr,
    input  wire [31:0] write_data,
    
    // Data outputs
    output reg  [31:0] rs1_data,
    output reg  [31:0] rs2_data,
    output wire [31:0] loaded_base_addr,
    
    // Status outputs
    output reg         rs1_read_done,
    output reg         rs2_read_done,
    output reg         write_done,
    output wire        store_rs1_base,
    output wire        store_rs2_base,
    output wire        store_rd_base,
    
    // AXI4-Lite Port A (RS1 Read and Address Loading)
    output reg  [31:0] axia_araddr,
    output reg         axia_arvalid,
    input  wire        axia_arready,
    input  wire [31:0] axia_rdata,
    input  wire [1:0]  axia_rresp,
    input  wire        axia_rvalid,
    output reg         axia_rready,
    
    // AXI4-Lite Port B (RS2 Read)
    output reg  [31:0] axib_araddr,
    output reg         axib_arvalid,
    input  wire        axib_arready,
    input  wire [31:0] axib_rdata,
    input  wire [1:0]  axib_rresp,
    input  wire        axib_rvalid,
    output reg         axib_rready,
    
    // AXI4-Lite Port C (RD Write)
    output reg  [31:0] axic_awaddr,
    output reg         axic_awvalid,
    input  wire        axic_awready,
    output reg  [31:0] axic_wdata,
    output reg         axic_wvalid,
    input  wire        axic_wready,
    input  wire [1:0]  axic_bresp,
    input  wire        axic_bvalid,
    output reg         axic_bready,
    
    // Error reporting
    output reg         error_flag,
    output reg  [1:0]  error_code
);

    // FSM States (local copy for reference)
    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] LOAD_ADDRESSES = 3'b001;
    localparam [2:0] EXECUTE_INIT   = 3'b010;
    localparam [2:0] EXECUTE_READ   = 3'b011;
    localparam [2:0] EXECUTE_WRITE  = 3'b100;
    localparam [2:0] DONE           = 3'b101;
    
    // Error codes
    localparam [1:0] NO_ERROR      = 2'b00;
    localparam [1:0] READ_ERROR    = 2'b01;
    localparam [1:0] WRITE_ERROR   = 2'b10;
    
    // Base address storage control - Fixed timing
    assign store_rs1_base = (current_state == LOAD_ADDRESSES) && (addr_load_counter == 2'd0) && axia_rvalid && axia_rready;
    assign store_rs2_base = (current_state == LOAD_ADDRESSES) && (addr_load_counter == 2'd1) && axia_rvalid && axia_rready;
    assign store_rd_base  = (current_state == LOAD_ADDRESSES) && (addr_load_counter == 2'd2) && axia_rvalid && axia_rready;
    assign loaded_base_addr = axia_rdata;
    
    // AXI Port A Control (Address Loading and RS1 Reads) - Fixed
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_araddr <= 32'h0;
            axia_arvalid <= 1'b0;
            axia_rready <= 1'b0;
            rs1_data <= 32'h0;
            rs1_read_done <= 1'b0;
        end else begin
            case (current_state)
                LOAD_ADDRESSES: begin
                    // Fixed: Handle address loading for all three base addresses
                    if (!axia_arvalid && !axia_rready) begin
                        axia_araddr <= base_ptr_addr;
                        axia_arvalid <= 1'b1;
                    end else if (axia_arvalid && axia_arready) begin
                        axia_arvalid <= 1'b0;
                        axia_rready <= 1'b1;
                    end else if (axia_rready && axia_rvalid) begin
                        axia_rready <= 1'b0;
                        // Base address will be stored via the store signals
                    end
                end
                
                EXECUTE_READ: begin
                    if (!rs1_read_done) begin
                        if (!axia_arvalid && !axia_rready) begin
                            axia_araddr <= rs1_element_addr;
                            axia_arvalid <= 1'b1;
                        end else if (axia_arvalid && axia_arready) begin
                            axia_arvalid <= 1'b0;
                            axia_rready <= 1'b1;
                        end else if (axia_rready && axia_rvalid) begin
                            rs1_data <= axia_rdata;
                            axia_rready <= 1'b0;
                            rs1_read_done <= 1'b1;
                            
                            if (axia_rresp != 2'b00) begin
                                error_flag <= 1'b1;
                                error_code <= READ_ERROR;
                            end
                        end
                    end
                end
                
                EXECUTE_INIT: begin
                    rs1_read_done <= 1'b0;
                end
                
                IDLE: begin
                    rs1_read_done <= 1'b0;
                end
            endcase
        end
    end
    
    // AXI Port B Control (RS2 Reads) - Fixed
    always @(posedge clk) begin
        if (!rst_n) begin
            axib_araddr <= 32'h0;
            axib_arvalid <= 1'b0;
            axib_rready <= 1'b0;
            rs2_data <= 32'h0;
            rs2_read_done <= 1'b0;
        end else begin
            case (current_state)
                EXECUTE_READ: begin
                    if (!rs2_read_done) begin
                        if (!axib_arvalid && !axib_rready) begin
                            axib_araddr <= rs2_element_addr;
                            axib_arvalid <= 1'b1;
                        end else if (axib_arvalid && axib_arready) begin
                            axib_arvalid <= 1'b0;
                            axib_rready <= 1'b1;
                        end else if (axib_rready && axib_rvalid) begin
                            rs2_data <= axib_rdata;
                            axib_rready <= 1'b0;
                            rs2_read_done <= 1'b1;
                            
                            if (axib_rresp != 2'b00) begin
                                error_flag <= 1'b1;
                                error_code <= READ_ERROR;
                            end
                        end
                    end
                end
                
                EXECUTE_INIT: begin
                    rs2_read_done <= 1'b0;
                end
                
                IDLE: begin
                    rs2_read_done <= 1'b0;
                end
            endcase
        end
    end
    
    // AXI Port C Control (RD Writes) - Fixed
    always @(posedge clk) begin
        if (!rst_n) begin
            axic_awaddr <= 32'h0;
            axic_awvalid <= 1'b0;
            axic_wdata <= 32'h0;
            axic_wvalid <= 1'b0;
            axic_bready <= 1'b0;
            write_done <= 1'b0;
        end else begin
            case (current_state)
                EXECUTE_WRITE: begin
                    if (!write_done) begin
                        // Start write transaction
                        if (!axic_awvalid && !axic_wvalid && !axic_bready) begin
                            axic_awaddr <= rd_element_addr;
                            axic_wdata <= write_data;
                            axic_awvalid <= 1'b1;
                            axic_wvalid <= 1'b1;
                        end
                        
                        // Handle address ready
                        if (axic_awvalid && axic_awready) begin
                            axic_awvalid <= 1'b0;
                        end
                        
                        // Handle data ready
                        if (axic_wvalid && axic_wready) begin
                            axic_wvalid <= 1'b0;
                        end
                        
                        // Wait for write response
                        if (!axic_awvalid && !axic_wvalid && !axic_bready) begin
                            axic_bready <= 1'b1;
                        end
                        
                        // Handle write response
                        if (axic_bready && axic_bvalid) begin
                            axic_bready <= 1'b0;
                            write_done <= 1'b1;
                            
                            if (axic_bresp != 2'b00) begin
                                error_flag <= 1'b1;
                                error_code <= WRITE_ERROR;
                            end
                        end
                    end
                end
                
                EXECUTE_INIT: begin
                    write_done <= 1'b0;
                end
                
                IDLE: begin
                    write_done <= 1'b0;
                end
            endcase
        end
    end
    
    // Error handling
    always @(posedge clk) begin
        if (!rst_n) begin
            error_flag <= 1'b0;
            error_code <= NO_ERROR;
        end else begin
            if (current_state == IDLE) begin
                error_flag <= 1'b0;
                error_code <= NO_ERROR;
            end
        end
    end

endmodule