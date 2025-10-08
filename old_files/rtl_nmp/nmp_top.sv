//-----------------------------------------------------------------------------
// Title         : NMP Top-Level Integration Module (Corrected)
// Project       : PULPino NMP Extension  
// Description   : Integrates all NMP sub-modules into a complete system
//-----------------------------------------------------------------------------

module nmp_top #(
    parameter [31:0] RS1_BASE_PTR_ADDR = 32'h00100000,
    parameter [31:0] RS2_BASE_PTR_ADDR = 32'h00100004,
    parameter [31:0] RD_BASE_PTR_ADDR  = 32'h00100008
) (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control Interface from PULPino
    input  wire [31:0] instruction,
    input  wire        instruction_valid,
    output wire        nmp_active,
    output wire        inter_flag,
    
    // Error Reporting
    output wire        error_flag,
    output wire [1:0]  error_code,
    
    // AXI4-Lite Port A (RS1 Read)
    output wire [31:0] axia_araddr,
    output wire        axia_arvalid,
    input  wire        axia_arready,
    input  wire [31:0] axia_rdata,
    input  wire [1:0]  axia_rresp,
    input  wire        axia_rvalid,
    output wire        axia_rready,
    
    // AXI4-Lite Port B (RS2 Read)
    output wire [31:0] axib_araddr,
    output wire        axib_arvalid,
    input  wire        axib_arready,
    input  wire [31:0] axib_rdata,
    input  wire [1:0]  axib_rresp,
    input  wire        axib_rvalid,
    output wire        axib_rready,
    
    // AXI4-Lite Port C (RD Write)
    output wire [31:0] axic_awaddr,
    output wire        axic_awvalid,
    input  wire        axic_awready,
    output wire [31:0] axic_wdata,
    output wire        axic_wvalid,
    input  wire        axic_wready,
    input  wire [1:0]  axic_bresp,
    input  wire        axic_bvalid,
    output wire        axic_bready
);

    //-------------------------------------------------------------------------
    // FSM State Parameters
    //-------------------------------------------------------------------------
    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] LOAD_ADDRESSES = 3'b001;
    localparam [2:0] EXECUTE_INIT   = 3'b010;
    localparam [2:0] EXECUTE_READ   = 3'b011;
    localparam [2:0] EXECUTE_WRITE  = 3'b100;
    localparam [2:0] DONE           = 3'b101;

    //-------------------------------------------------------------------------
    // Internal Signal Declarations
    //-------------------------------------------------------------------------
    
    // Decoder outputs
    wire        is_nmp_add;
    wire [4:0]  array_size;
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    
    // FSM signals
    wire [2:0]  current_state;
    wire        start_addr_load;
    wire        start_element_read;
    wire        start_element_write;
    wire        increment_element;
    wire        operation_complete;
    
    // Address generation signals
    wire [31:0] base_ptr_addr;
    wire [31:0] rs1_element_addr;
    wire [31:0] rs2_element_addr;
    wire [31:0] rd_element_addr;
    
    // Base address storage
    reg  [31:0] rs1_base_addr;
    reg  [31:0] rs2_base_addr;
    reg  [31:0] rd_base_addr;
    
    wire        store_rs1_base;
    wire        store_rs2_base;
    wire        store_rd_base;
    
    // ALU signals
    wire [31:0] alu_result;
    wire        alu_overflow;
    wire        alu_zero;
    
    // AXI master signals
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] loaded_base_addr;
    wire        rs1_read_done;
    wire        rs2_read_done;
    wire        write_done;
    
    // Internal counters and registers
    reg  [1:0]  addr_load_counter;
    reg  [4:0]  element_counter;
    
    //-------------------------------------------------------------------------
    // Base Address Storage Logic
    //-------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if (!rst_n) begin
            rs1_base_addr <= 32'h0;
            rs2_base_addr <= 32'h0;
            rd_base_addr  <= 32'h0;
        end else begin
            if (store_rs1_base) begin
                rs1_base_addr <= loaded_base_addr;
            end
            if (store_rs2_base) begin
                rs2_base_addr <= loaded_base_addr;
            end
            if (store_rd_base) begin
                rd_base_addr <= loaded_base_addr;
            end
        end
    end
    
    //-------------------------------------------------------------------------
    // Counter Management
    //-------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if (!rst_n) begin
            addr_load_counter <= 2'h0;
            element_counter <= 5'h0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (is_nmp_add) begin
                        addr_load_counter <= 2'h0;
                        element_counter <= 5'h0;
                    end
                end
                
                LOAD_ADDRESSES: begin
                    if (store_rs1_base || store_rs2_base || store_rd_base) begin
                        addr_load_counter <= addr_load_counter + 1;
                    end
                end
            endcase

            // The 'increment_element' signal from the FSM is the sole trigger for this counter.
            // It is asserted for one cycle after a write completes. We should not check the FSM state
            // here, as it will have already changed by the time this logic executes, causing the bug.
            if (increment_element) begin
                element_counter <= element_counter + 1;
            end
        end
    end
    
    //-------------------------------------------------------------------------
    // Module Instantiations
    //-------------------------------------------------------------------------
    
    // Instruction Decoder
    nmp_decoder u_decoder (
        .instruction      (instruction),
        .instruction_valid(instruction_valid),
        .is_nmp_add       (is_nmp_add),
        .array_size       (array_size),
        .opcode           (opcode),
        .funct3           (funct3),
        .funct7           (funct7)
    );
    
    // FSM Controller
    nmp_fsm u_fsm (
        .clk                 (clk),
        .rst_n               (rst_n),
        .is_nmp_add          (is_nmp_add),
        .array_size          (array_size),
        .addr_load_counter   (addr_load_counter),
        .element_counter     (element_counter),
        .rs1_read_done       (rs1_read_done),
        .rs2_read_done       (rs2_read_done),
        .write_done          (write_done),
        .nmp_active          (nmp_active),
        .inter_flag          (inter_flag),
        .current_state       (current_state),
        .start_addr_load     (start_addr_load),
        .start_element_read  (start_element_read),
        .start_element_write (start_element_write),
        .increment_element   (increment_element),
        .operation_complete  (operation_complete)
    );
    
    // Address Generation Unit
    nmp_addr_gen #(
        .RS1_BASE_PTR_ADDR(RS1_BASE_PTR_ADDR),
        .RS2_BASE_PTR_ADDR(RS2_BASE_PTR_ADDR),
        .RD_BASE_PTR_ADDR (RD_BASE_PTR_ADDR)
    ) u_addr_gen (
        .clk               (clk),
        .rst_n             (rst_n),
        .addr_load_counter (addr_load_counter),
        .element_counter   (element_counter),
        .rs1_base_addr     (rs1_base_addr),
        .rs2_base_addr     (rs2_base_addr),
        .rd_base_addr      (rd_base_addr),
        .base_ptr_addr     (base_ptr_addr),
        .rs1_element_addr  (rs1_element_addr),
        .rs2_element_addr  (rs2_element_addr),
        .rd_element_addr   (rd_element_addr)
    );
    
    // ALU
    nmp_alu u_alu (
        .operand_a (rs1_data),
        .operand_b (rs2_data),
        .operation (3'b000),    // Always addition for now
        .result    (alu_result),
        .overflow  (alu_overflow),
        .zero      (alu_zero)
    );
    
    // AXI Master Interface
    nmp_axi_master u_axi_master (
        .clk                 (clk),
        .rst_n               (rst_n),
        .current_state       (current_state),
        .start_addr_load     (start_addr_load),
        .start_element_read  (start_element_read),
        .start_element_write (start_element_write),
        .addr_load_counter   (addr_load_counter),
        .base_ptr_addr       (base_ptr_addr),
        .rs1_element_addr    (rs1_element_addr),
        .rs2_element_addr    (rs2_element_addr),
        .rd_element_addr     (rd_element_addr),
        .write_data          (alu_result),
        .rs1_data            (rs1_data),
        .rs2_data            (rs2_data),
        .loaded_base_addr    (loaded_base_addr),
        .rs1_read_done       (rs1_read_done),
        .rs2_read_done       (rs2_read_done),
        .write_done          (write_done),
        .store_rs1_base      (store_rs1_base),
        .store_rs2_base      (store_rs2_base),
        .store_rd_base       (store_rd_base),
        .axia_araddr         (axia_araddr),
        .axia_arvalid        (axia_arvalid),
        .axia_arready        (axia_arready),
        .axia_rdata          (axia_rdata),
        .axia_rresp          (axia_rresp),
        .axia_rvalid         (axia_rvalid),
        .axia_rready         (axia_rready),
        .axib_araddr         (axib_araddr),
        .axib_arvalid        (axib_arvalid),
        .axib_arready        (axib_arready),
        .axib_rdata          (axib_rdata),
        .axib_rresp          (axib_rresp),
        .axib_rvalid         (axib_rvalid),
        .axib_rready         (axib_rready),
        .axic_awaddr         (axic_awaddr),
        .axic_awvalid        (axic_awvalid),
        .axic_awready        (axic_awready),
        .axic_wdata          (axic_wdata),
        .axic_wvalid         (axic_wvalid),
        .axic_wready         (axic_wready),
        .axic_bresp          (axic_bresp),
        .axic_bvalid         (axic_bvalid),
        .axic_bready         (axic_bready),
        .error_flag          (error_flag),
        .error_code          (error_code)
    );

endmodule


