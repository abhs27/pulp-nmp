//-----------------------------------------------------------------------------
// Title         : NMP Address Lookup Table (ALT)
// Project       : PULPino NMP Extension - Hash-Based Address Lookup
// Description   : Stores base addresses indexed by 17-bit hash
//                 Each entry contains: rs1_base[31:0], rs2_base[31:0], rd_base[31:0]
//                 Total entries: 131,072 (2^17)
//-----------------------------------------------------------------------------

module nmp_address_lookup_table (
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
    output reg         read_valid
);

    // Address Lookup Table Storage
    // Each entry: 96 bits = 3 x 32-bit addresses
    // Total size: 131,072 entries x 96 bits = 12,582,912 bits ≈ 1.5 MB
    reg [31:0] alt_rs1_base [0:131071];
    reg [31:0] alt_rs2_base [0:131071];
    reg [31:0] alt_rd_base  [0:131071];
    
    // Initialization flag to track if entries are valid
    reg [131071:0] valid_entries;
    
    //-------------------------------------------------------------------------
    // Reset and Initialization
    //-------------------------------------------------------------------------
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear valid entries bitmap
            valid_entries <= {131072{1'b0}};
            read_valid <= 1'b0;
            read_rs1_base <= 32'h0;
            read_rs2_base <= 32'h0;
            read_rd_base  <= 32'h0;
        end else begin
            // Write operation
            if (write_enable) begin
                alt_rs1_base[write_hash_index] <= write_rs1_base;
                alt_rs2_base[write_hash_index] <= write_rs2_base;
                alt_rd_base[write_hash_index]  <= write_rd_base;
                valid_entries[write_hash_index] <= 1'b1;
            end
            
            // Read operation
            if (read_enable) begin
                read_rs1_base <= alt_rs1_base[read_hash_index];
                read_rs2_base <= alt_rs2_base[read_hash_index];
                read_rd_base  <= alt_rd_base[read_hash_index];
                read_valid    <= valid_entries[read_hash_index];
            end else begin
                read_valid <= 1'b0;
            end
        end
    end

endmodule
