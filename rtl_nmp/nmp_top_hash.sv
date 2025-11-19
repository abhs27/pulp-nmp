//-----------------------------------------------------------------------------
// Title         : NMP Top-Level with Hash-Based Address Lookup
// Project       : PULPino NMP Extension - Hash Mode
// Description   : Integrates hash-based address lookup with legacy mode support
//                 Supports both modes:
//                 - Legacy: Load base addresses from memory
//                 - Hash: Retrieve base addresses from ALT using instruction hash
//-----------------------------------------------------------------------------

module nmp_top_hash #(
    parameter [31:0] RS1_BASE_PTR_ADDR = 32'h00100000,
    parameter [31:0] RS2_BASE_PTR_ADDR = 32'h00100004,
    parameter [31:0] RD_BASE_PTR_ADDR  = 32'h00100008,
    parameter        HASH_MODE_ENABLE  = 1'b1  // Enable hash-based addressing
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
    output wire        hash_error,          // NEW: Hash lookup error
    
    // ALT Write Interface (for initialization)
    input  wire        alt_write_enable,
    input  wire [16:0] alt_write_hash_index,
    input  wire [31:0] alt_write_rs1_base,
    input  wire [31:0] alt_write_rs2_base,
    input  wire [31:0] alt_write_rd_base,
    
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
    // Internal Signal Declarations
    //-------------------------------------------------------------------------
    
    // Decoder outputs
    wire        nmp_valid_start;
    wire [4:0]  array_size;
    wire [16:0] hash_index;
    wire        use_hash_mode;
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    
    // FSM signals
    wire [3:0]  current_state;
    wire        start_addr_load;
    wire        start_hash_lookup;
    wire        start_element_read;
    wire        start_element_write;
    wire        increment_element;
    wire        operation_complete;

    wire        start_op;
    wire        op_done;
    
    // Address generation signals
    wire [31:0] base_ptr_addr;
    wire [31:0] rs1_element_addr;
    wire [31:0] rs2_element_addr;
    wire [31:0] rd_element_addr;
    
    // Base address storage (muxed from legacy or hash mode)
    reg  [31:0] rs1_base_addr;
    reg  [31:0] rs2_base_addr;
    reg  [31:0] rd_base_addr;
    
    wire        store_rs1_base;
    wire        store_rs2_base;
    wire        store_rd_base;
    
    // Hash lookup signals
    wire        hash_lookup_enable;
    wire [31:0] hash_rs1_base;
    wire [31:0] hash_rs2_base;
    wire [31:0] hash_rd_base;
    wire        hash_addr_valid;
    wire        hash_addr_not_found;
    
    // ALT interface signals
    wire        alt_read_enable;
    wire [16:0] alt_read_hash_index;
    wire [31:0] alt_read_rs1_base;
    wire [31:0] alt_read_rs2_base;
    wire [31:0] alt_read_rd_base;
    wire        alt_read_valid;
    
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
    // Base Address Mux: Select between legacy and hash mode
    //-------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if (!rst_n) begin
            rs1_base_addr <= 32'h0;
            rs2_base_addr <= 32'h0;
            rd_base_addr  <= 32'h0;
        end else begin
            // Hash mode: Load from hash lookup
            if (use_hash_mode && hash_addr_valid) begin
                rs1_base_addr <= hash_rs1_base;
                rs2_base_addr <= hash_rs2_base;
                rd_base_addr  <= hash_rd_base;
            end
            // Legacy mode: Load from memory
            else begin
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
                4'b0000: begin // IDLE
                    if (nmp_valid_start) begin
                        addr_load_counter <= 2'h0;
                        element_counter <= 5'h0;
                    end
                end
                
                4'b0001: begin // LOAD_ADDRESSES
                    if (store_rs1_base || store_rs2_base || store_rd_base) begin
                        addr_load_counter <= addr_load_counter + 1;
                    end
                end
            endcase

            if (increment_element) begin
                element_counter <= element_counter + 1;
            end
        end
    end
    
    // Hash lookup enable signal
    assign hash_lookup_enable = start_hash_lookup;
    
    //-------------------------------------------------------------------------
    // Module Instantiations
    //-------------------------------------------------------------------------
    
    // Instruction Decoder with Hash Support
    nmp_decoder_hash u_decoder (
        .instruction        (instruction),
        .instruction_valid  (instruction_valid),
        .hash_mode_enable   (HASH_MODE_ENABLE),
        .nmp_valid_start    (nmp_valid_start),
        .array_size         (array_size),
        .hash_index         (hash_index),
        .use_hash_mode      (use_hash_mode),
        .opcode             (opcode),
        .funct3             (funct3),
        .funct7             (funct7)
    );
    
    // FSM Controller with Hash Support
    nmp_fsm_hash u_fsm (
        .clk                  (clk),
        .rst_n                (rst_n),
        .nmp_valid_start    (nmp_valid_start),
        .use_hash_mode        (use_hash_mode),
        .array_size           (array_size),
        .addr_load_counter    (addr_load_counter),
        .element_counter      (element_counter),
        .rs1_read_done        (rs1_read_done),
        .rs2_read_done        (rs2_read_done),
        .write_done           (write_done),
        .hash_addr_valid      (hash_addr_valid),
        .hash_addr_not_found  (hash_addr_not_found),
        .nmp_active           (nmp_active),
        .inter_flag           (inter_flag),
        .current_state        (current_state),
        .start_addr_load      (start_addr_load),
        .start_hash_lookup    (start_hash_lookup),
        .start_element_read   (start_element_read),
        .start_element_write  (start_element_write),
        .increment_element    (increment_element),
        .operation_complete   (operation_complete),
        .hash_error           (hash_error),
        .start_op             (start_op),
        .op_done              (op_done),
        .funct3               (funct3)
    );
    
    // Address Lookup Table
    nmp_address_lookup_table u_alt (
        .clk                (clk),
        .rst_n              (rst_n),
        .write_enable       (alt_write_enable),
        .write_hash_index   (alt_write_hash_index),
        .write_rs1_base     (alt_write_rs1_base),
        .write_rs2_base     (alt_write_rs2_base),
        .write_rd_base      (alt_write_rd_base),
        .read_enable        (alt_read_enable),
        .read_hash_index    (alt_read_hash_index),
        .read_rs1_base      (alt_read_rs1_base),
        .read_rs2_base      (alt_read_rs2_base),
        .read_rd_base       (alt_read_rd_base),
        .read_valid         (alt_read_valid)
    );
    
    // Hash Address Decoder
    nmp_hash_addr_decoder u_hash_decoder (
        .clk                  (clk),
        .rst_n                (rst_n),
        .lookup_enable        (hash_lookup_enable),
        .hash_index           (hash_index),
        .rs1_base_addr        (hash_rs1_base),
        .rs2_base_addr        (hash_rs2_base),
        .rd_base_addr         (hash_rd_base),
        .addr_valid           (hash_addr_valid),
        .addr_not_found       (hash_addr_not_found),
        .alt_read_enable      (alt_read_enable),
        .alt_read_hash_index  (alt_read_hash_index),
        .alt_read_rs1_base    (alt_read_rs1_base),
        .alt_read_rs2_base    (alt_read_rs2_base),
        .alt_read_rd_base     (alt_read_rd_base),
        .alt_read_valid       (alt_read_valid)
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
        .clk       (clk),
        .rst_n     (rst_n),
        .start_op   (start_op),
        .operand_a (rs1_data),
        .operand_b (rs2_data),
        .operation (funct3),
        .op_done   (op_done),
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
