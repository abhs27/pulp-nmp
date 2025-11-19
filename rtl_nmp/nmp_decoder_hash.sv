//-----------------------------------------------------------------------------
// Title         : NMP Instruction Decoder with Hash Support
// Project       : PULPino NMP Extension - Hash-Based Address Lookup
// Description   : Decodes custom NMP instructions with hash-based addressing
//                 Instruction Format (32 bits):
//                 [31:15] - 17-bit hash index (when hash_mode enabled)
//                 [14:12] - funct3 (operation type)
//                 [11:7]  - array_size (5 bits)
//                 [6:0]   - opcode (0x6b for NMP)
//-----------------------------------------------------------------------------

module nmp_decoder_hash (
    // Inputs
    input  wire [31:0] instruction,
    input  wire        instruction_valid,
    input  wire        hash_mode_enable,    // NEW: Enable hash-based addressing
    
    // Outputs
    output wire        nmp_valid_start,           // NEW: Support for SUB operation
    output wire [4:0]  array_size,
    output wire [16:0] hash_index,          // NEW: 17-bit hash for ALT lookup
    output wire        use_hash_mode,       // NEW: Indicates hash mode is active
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7
);

    // Instruction format constants
    localparam [6:0] OPCODE_NMP     = 7'b1101011;  // 0x6b - Dedicated NMP opcode
    localparam [2:0] FUNCT3_NMP_ADD = 3'b000;      // ADD operation
    localparam [2:0] FUNCT3_NMP_SUB = 3'b001;      // SUB operation (future)
    localparam [2:0] FUNCT3_NMP_MUL = 3'b010;      // MUL operation (future)
    localparam [2:0] FUNCT3_NMP_DIV = 3'b011;      // DIV operation (future)
    
    // Hash mode enable bit (bit 14) - can be used as mode selector
    // When bit[14] = 1, use hash mode; when 0, use legacy mode
    // wire hash_mode_bit;
    // assign hash_mode_bit = instruction[14];
    // currently using hash mode bit as third bit for funct3 to accomodate fft ops

    // Extract instruction fields
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];  // Only 2 bits used, bit 14 is hash mode flag
    assign array_size = instruction[11:7];  // Size field
    assign funct7 = instruction[31:25];     // Not used in hash mode
    
    // Extract 17-bit hash index from instruction bits [31:15]
    assign hash_index = instruction[31:15];
    
    // Determine if hash mode should be used
    // Hash mode is active when: hash_mode_enable AND instruction bit[14] is set
    assign use_hash_mode = hash_mode_enable;

    wire is_nmp_add, is_nmp_sub, is_nmp_mul, is_nmp_div;
    // Decode NMP_ADD instruction
    assign is_nmp_add = instruction_valid && 
                       (opcode == OPCODE_NMP) && 
                       (funct3[2:0] == FUNCT3_NMP_ADD);  // Check only lower 2 bits for ADD

    assign is_nmp_sub = instruction_valid && 
                       (opcode == OPCODE_NMP) && 
                       (funct3[2:0] == FUNCT3_NMP_SUB);  // Check only lower 2 bits for ADD

    assign is_nmp_mul = instruction_valid && 
                       (opcode == OPCODE_NMP) && 
                       (funct3[2:0] == FUNCT3_NMP_MUL);  // Check only lower 2 bits for MUL

    assign is_nmp_div = instruction_valid && 
                       (opcode == OPCODE_NMP) && 
                       (funct3[2:0] == FUNCT3_NMP_DIV);  // Check only lower 2 bits for DIV

    assign nmp_valid_start = is_nmp_add || is_nmp_sub || is_nmp_mul || is_nmp_div;

endmodule
