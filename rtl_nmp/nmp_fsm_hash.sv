//-----------------------------------------------------------------------------
// Title         : NMP FSM Controller with Hash Support
// Project       : PULPino NMP Extension - Hash-Based Address Lookup
// Description   : FSM with support for hash-based address lookup
//                 When hash mode is enabled, skips LOAD_ADDRESSES state
//-----------------------------------------------------------------------------

module nmp_fsm_hash (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control Inputs
    input  wire        is_nmp_add,
    input  wire        use_hash_mode,       // NEW: Use hash-based addressing
    input  wire [4:0]  array_size,
    input  wire [1:0]  addr_load_counter,
    input  wire [4:0]  element_counter,
    input  wire        rs1_read_done,
    input  wire        rs2_read_done,
    input  wire        write_done,
    input  wire        hash_addr_valid,     // NEW: Hash lookup complete
    input  wire        hash_addr_not_found, // NEW: Hash not found error
    
    // Status Outputs
    output reg         nmp_active,
    output reg         inter_flag,
    output wire [2:0]  current_state,
    
    // Control Outputs
    output reg         start_addr_load,
    output reg         start_hash_lookup,   // NEW: Trigger hash lookup
    output reg         start_element_read,
    output reg         start_element_write,
    output reg         increment_element,
    output reg         operation_complete,
    output reg         hash_error           // NEW: Hash lookup error
);

    // FSM States
    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] LOAD_ADDRESSES = 3'b001;
    localparam [2:0] HASH_LOOKUP    = 3'b110;  // NEW: Hash lookup state
    localparam [2:0] EXECUTE_INIT   = 3'b010;
    localparam [2:0] EXECUTE_READ   = 3'b011;
    localparam [2:0] EXECUTE_WRITE  = 3'b100;
    localparam [2:0] DONE           = 3'b101;
    localparam [2:0] ERROR          = 3'b111;  // NEW: Error state
    
    // State registers
    reg [2:0] state, next_state;
    reg [4:0] stored_array_size;
    
    assign current_state = state;
    
    // State register
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            stored_array_size <= 5'h0;
        end else begin
            state <= next_state;
            if (state == IDLE && is_nmp_add) begin
                stored_array_size <= array_size;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (is_nmp_add) begin
                    if (use_hash_mode) begin
                        next_state = HASH_LOOKUP;  // Skip to hash lookup
                    end else begin
                        next_state = LOAD_ADDRESSES;  // Legacy mode
                    end
                end
            end
            
            LOAD_ADDRESSES: begin
                if (addr_load_counter == 2'd3) begin
                    next_state = EXECUTE_INIT;
                end
            end
            
            HASH_LOOKUP: begin
                if (hash_addr_valid) begin
                    next_state = EXECUTE_INIT;  // Addresses retrieved
                end else if (hash_addr_not_found) begin
                    next_state = ERROR;  // Hash not found
                end
            end
            
            EXECUTE_INIT: begin
                next_state = EXECUTE_READ;
            end
            
            EXECUTE_READ: begin
                if (rs1_read_done && rs2_read_done) begin
                    next_state = EXECUTE_WRITE;
                end
            end
            
            EXECUTE_WRITE: begin
                if (write_done) begin
                    if ((element_counter + 1) >= stored_array_size) begin
                        next_state = DONE;
                    end else begin
                        next_state = EXECUTE_INIT;
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;  // Return to idle on error
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output logic
    always @(posedge clk) begin
        if (!rst_n) begin
            nmp_active <= 1'b0;
            inter_flag <= 1'b0;
            start_addr_load <= 1'b0;
            start_hash_lookup <= 1'b0;
            start_element_read <= 1'b0;
            start_element_write <= 1'b0;
            increment_element <= 1'b0;
            operation_complete <= 1'b0;
            hash_error <= 1'b0;
        end else begin
            // Default values for control signals
            start_addr_load <= 1'b0;
            start_hash_lookup <= 1'b0;
            start_element_read <= 1'b0;
            start_element_write <= 1'b0;
            increment_element <= 1'b0;
            operation_complete <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (is_nmp_add) begin
                        nmp_active <= 1'b1;
                        inter_flag <= 1'b0;
                        hash_error <= 1'b0;
                    end
                end
                
                LOAD_ADDRESSES: begin
                    start_addr_load <= 1'b1;
                end
                
                HASH_LOOKUP: begin
                    start_hash_lookup <= 1'b1;
                end
                
                EXECUTE_READ: begin
                    start_element_read <= 1'b1;
                end
                
                EXECUTE_WRITE: begin
                    start_element_write <= 1'b1;
                    if (write_done) begin
                        increment_element <= 1'b1;
                    end
                end
                
                DONE: begin
                    nmp_active <= 1'b0;
                    inter_flag <= 1'b1;
                    operation_complete <= 1'b1;
                end
                
                ERROR: begin
                    nmp_active <= 1'b0;
                    hash_error <= 1'b1;
                    inter_flag <= 1'b1;  // Signal completion (with error)
                end
            endcase
        end
    end

endmodule
