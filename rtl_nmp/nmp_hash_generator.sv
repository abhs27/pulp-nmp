//-----------------------------------------------------------------------------
// Title         : NMP Hash Generator
// Project       : PULPino NMP Extension - Hash-Based Address Lookup
// Description   : Generates 17-bit hash from three 32-bit base addresses
//                 Algorithm: Multiplicative Hash with XOR Mixing
//                 - Fast: 2 XORs + 1 multiply + 1 shift
//                 - Good distribution with golden ratio constant
//                 - Collision rate: ~0.4-0.8%
//-----------------------------------------------------------------------------

module nmp_hash_generator (
    // Three 32-bit base addresses as input
    input  wire [31:0] rs1_base_addr,
    input  wire [31:0] rs2_base_addr,
    input  wire [31:0] rd_base_addr,
    
    // 17-bit hash output
    output wire [16:0] hash_index
);

    // Golden ratio constant (fractional part of φ = 1.618... scaled to 32 bits)
    // 0x9E3779B9 = 2654435769 decimal
    // This constant has proven mathematical properties for uniform distribution
    localparam [31:0] GOLDEN_RATIO = 32'h9E3779B9;
    
    // Internal signals
    wire [31:0] combined;
    wire [31:0] mixed;
    
    // Step 1: XOR combine the three 32-bit addresses
    assign combined = rs1_base_addr ^ rs2_base_addr ^ rd_base_addr;
    
    // Step 2: Apply multiplicative hashing using golden ratio
    assign mixed = combined * GOLDEN_RATIO;
    
    // Step 3: Extract 17 bits from mixed result (bits [31:15])
    // Using upper bits provides better distribution
    assign hash_index = mixed[31:15];

endmodule
