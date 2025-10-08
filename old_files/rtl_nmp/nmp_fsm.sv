//-----------------------------------------------------------------------------
// Title         : NMP Finite State Machine Controller (Corrected)
// Project       : PULPino NMP Extension
// Description   : Controls the NMP operation sequence and state transitions
//-----------------------------------------------------------------------------

module nmp_fsm (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control Inputs
    input  wire        is_nmp_add,
    input  wire [4:0]  array_size,
    input  wire [1:0]  addr_load_counter,
    input  wire [4:0]  element_counter,
    input  wire        rs1_read_done,
    input  wire        rs2_read_done,
    input  wire        write_done,
    
    // Status Outputs
    output reg         nmp_active,
    output reg         inter_flag,
    output wire [2:0]  current_state,
    
    // Control Outputs
    output reg         start_addr_load,
    output reg         start_element_read,
    output reg         start_element_write,
    output reg         increment_element,
    output reg         operation_complete
);

    // FSM States
    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] LOAD_ADDRESSES = 3'b001;
    localparam [2:0] EXECUTE_INIT   = 3'b010;
    localparam [2:0] EXECUTE_READ   = 3'b011;
    localparam [2:0] EXECUTE_WRITE  = 3'b100;
    localparam [2:0] DONE           = 3'b101;
    
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
                    next_state = LOAD_ADDRESSES;
                end
            end
            
            LOAD_ADDRESSES: begin
                if (addr_load_counter == 2'd3) begin
                    next_state = EXECUTE_INIT;
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
            start_element_read <= 1'b0;
            start_element_write <= 1'b0;
            increment_element <= 1'b0;
            operation_complete <= 1'b0;
        end else begin
            // Default values for control signals
            start_addr_load <= 1'b0;
            start_element_read <= 1'b0;
            start_element_write <= 1'b0;
            increment_element <= 1'b0;
            operation_complete <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (is_nmp_add) begin
                        nmp_active <= 1'b1;
                        inter_flag <= 1'b0; // Clear the flag on a new operation
                    end
                end
                
                LOAD_ADDRESSES: begin
                    start_addr_load <= 1'b1;
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
                    inter_flag <= 1'b1; // Set the flag and keep it high
                    operation_complete <= 1'b1;
                end
            endcase
        end
    end

endmodule

