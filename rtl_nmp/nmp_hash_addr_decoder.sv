//-----------------------------------------------------------------------------
// Title         : NMP Hash Address Decoder
// Project       : PULPino NMP Extension - Hash-Based Address Lookup
// Description   : Retrieves base addresses from ALT using hash index
//                 Single-cycle lookup with 1-cycle latency
//-----------------------------------------------------------------------------

module nmp_hash_addr_decoder (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control Interface
    input  wire        lookup_enable,       // Start lookup
    input  wire [16:0] hash_index,          // 17-bit hash from instruction
    
    // Output Base Addresses
    output reg  [31:0] rs1_base_addr,
    output reg  [31:0] rs2_base_addr,
    output reg  [31:0] rd_base_addr,
    output reg         addr_valid,          // Addresses are valid
    output reg         addr_not_found,      // Hash not found in ALT (error)
    
    // Interface to Address Lookup Table
    output wire        alt_read_enable,
    output wire [16:0] alt_read_hash_index,
    input  wire [31:0] alt_read_rs1_base,
    input  wire [31:0] alt_read_rs2_base,
    input  wire [31:0] alt_read_rd_base,
    input  wire        alt_read_valid
);

    // State machine for lookup
    localparam [1:0] IDLE       = 2'b00;
    localparam [1:0] LOOKUP     = 2'b01;
    localparam [1:0] VALIDATE   = 2'b10;
    
    reg [1:0] state, next_state;
    
    // Connect to ALT
    assign alt_read_enable = (state == LOOKUP);
    assign alt_read_hash_index = hash_index;
    
    //-------------------------------------------------------------------------
    // State Machine
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (lookup_enable) begin
                    next_state = LOOKUP;
                end
            end
            
            LOOKUP: begin
                next_state = VALIDATE;
            end
            
            VALIDATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //-------------------------------------------------------------------------
    // Output Logic
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs1_base_addr  <= 32'h0;
            rs2_base_addr  <= 32'h0;
            rd_base_addr   <= 32'h0;
            addr_valid     <= 1'b0;
            addr_not_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    addr_valid <= 1'b0;
                    addr_not_found <= 1'b0;
                end
                
                LOOKUP: begin
                    // Wait for ALT to respond
                    addr_valid <= 1'b0;
                end
                
                VALIDATE: begin
                    if (alt_read_valid) begin
                        // Valid entry found
                        rs1_base_addr  <= alt_read_rs1_base;
                        rs2_base_addr  <= alt_read_rs2_base;
                        rd_base_addr   <= alt_read_rd_base;
                        addr_valid     <= 1'b1;
                        addr_not_found <= 1'b0;
                    end else begin
                        // Entry not found (hash collision or not initialized)
                        rs1_base_addr  <= 32'h0;
                        rs2_base_addr  <= 32'h0;
                        rd_base_addr   <= 32'h0;
                        addr_valid     <= 1'b0;
                        addr_not_found <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
