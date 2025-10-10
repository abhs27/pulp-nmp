//-----------------------------------------------------------------------------
// Title         : NMP Address Lookup Table (ALT) - COMPRESSED VERSION
// Project       : PULPino NMP Extension - Base+Offset Encoding
// Description   : Stores base addresses using compression:
//                 - rs1_base: Full 32-bit address (lowest)
//                 - rs2_offset: 16-bit signed offset from rs1_base
//                 - rd_offset: 16-bit signed offset from rs1_base
//                 
//                 Storage per entry: 64 bits (vs. 96 bits original)
//                 Total entries: 131,072 (2^17)
//                 Total size: 1.0 MB (vs. 1.5 MB original) - 33% SAVINGS!
//                 
//                 Max offset range: ±256 KB from rs1_base
//-----------------------------------------------------------------------------

module nmp_address_lookup_table_compressed #(
    parameter OFFSET_BITS = 16  // Configurable: 12, 16, 20, or 24 bits
) (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Write Interface (for compiler/initialization)
    input  wire        write_enable,
    input  wire [16:0] write_hash_index,
    input  wire [31:0] write_rs1_base,
    input  wire [31:0] write_rs2_base,
    input  wire [31:0] write_rd_base,
    
    // Read Interface (for NMP execution)
    input  wire        read_enable,
    input  wire [16:0] read_hash_index,
    output reg  [31:0] read_rs1_base,
    output reg  [31:0] read_rs2_base,
    output reg  [31:0] read_rd_base,
    output reg         read_valid,
    output reg         offset_overflow_error  // NEW: Error if offset too large
);

    //-------------------------------------------------------------------------
    // Address Lookup Table Storage - COMPRESSED FORMAT
    //-------------------------------------------------------------------------
    // Each entry: 32 + 2*OFFSET_BITS bits (default: 64 bits)
    // Total size with 16-bit offsets: 131,072 entries × 64 bits = 1.0 MB
    // Savings: 0.5 MB (33% reduction from 1.5 MB)
    
    reg [31:0]              alt_rs1_base   [0:131071];  // Full 32-bit base address
    reg signed [OFFSET_BITS-1:0]   alt_rs2_offset [0:131071];  // Signed offset (bytes)
    reg signed [OFFSET_BITS-1:0]   alt_rd_offset  [0:131071];  // Signed offset (bytes)
    
    // Initialization flag to track if entries are valid
    reg [131071:0] valid_entries;
    
    //-------------------------------------------------------------------------
    // Temporary storage for compression check during write
    //-------------------------------------------------------------------------
    reg signed [31:0] rs2_delta;
    reg signed [31:0] rd_delta;
    
    //-------------------------------------------------------------------------
    // Maximum representable offset (16-bit signed: -32768 to +32767)
    //-------------------------------------------------------------------------
    localparam signed [31:0] MAX_OFFSET = (2**(OFFSET_BITS-1)) - 1;  // +32767
    localparam signed [31:0] MIN_OFFSET = -(2**(OFFSET_BITS-1));      // -32768
    
    //-------------------------------------------------------------------------
    // Reset and Initialization
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear valid entries bitmap
            valid_entries <= {131072{1'b0}};
            read_valid <= 1'b0;
            read_rs1_base <= 32'h0;
            read_rs2_base <= 32'h0;
            read_rd_base  <= 32'h0;
            offset_overflow_error <= 1'b0;
        end else begin
            //---------------------------------------------------------------------
            // Write operation - COMPRESS addresses to base+offset
            //---------------------------------------------------------------------
            if (write_enable) begin
                // Calculate offsets as signed differences
                rs2_delta = $signed(write_rs2_base) - $signed(write_rs1_base);
                rd_delta  = $signed(write_rd_base)  - $signed(write_rs1_base);
                
                // Check for overflow (offsets too large to fit)
                if (rs2_delta > MAX_OFFSET || rs2_delta < MIN_OFFSET ||
                    rd_delta  > MAX_OFFSET || rd_delta  < MIN_OFFSET) begin
                    // ERROR: Offsets don't fit in specified bit width
                    offset_overflow_error <= 1'b1;
                    // Don't write the entry - keep valid bit as 0
                end else begin
                    // Store compressed entry
                    alt_rs1_base[write_hash_index]   <= write_rs1_base;
                    alt_rs2_offset[write_hash_index] <= rs2_delta[OFFSET_BITS-1:0];
                    alt_rd_offset[write_hash_index]  <= rd_delta[OFFSET_BITS-1:0];
                    valid_entries[write_hash_index]  <= 1'b1;
                    offset_overflow_error <= 1'b0;
                end
            end else begin
                offset_overflow_error <= 1'b0;
            end
            
            //---------------------------------------------------------------------
            // Read operation - DECOMPRESS base+offset to full addresses
            //---------------------------------------------------------------------
            if (read_enable) begin
                if (valid_entries[read_hash_index]) begin
                    // Read base address directly
                    read_rs1_base <= alt_rs1_base[read_hash_index];
                    
                    // Calculate full addresses by sign-extending offsets and adding to base
                    // Sign extension: replicate MSB to fill upper bits
                    read_rs2_base <= $signed(alt_rs1_base[read_hash_index]) + 
                                     $signed(alt_rs2_offset[read_hash_index]);
                    
                    read_rd_base  <= $signed(alt_rs1_base[read_hash_index]) + 
                                     $signed(alt_rd_offset[read_hash_index]);
                    
                    read_valid <= 1'b1;
                end else begin
                    // Entry not valid
                    read_rs1_base <= 32'h0;
                    read_rs2_base <= 32'h0;
                    read_rd_base  <= 32'h0;
                    read_valid    <= 1'b0;
                end
            end else begin
                read_valid <= 1'b0;
            end
        end
    end

endmodule
