//-----------------------------------------------------------------------------
// Title         : NMP Instruction Decoder
// Project       : PULPino NMP Extension
// Description   : Decodes custom NMP instructions using dedicated 0x6b opcode
//-----------------------------------------------------------------------------

module nmp_decoder (
    // Inputs
    input  wire [31:0] instruction,
    input  wire        instruction_valid,
    
    // Outputs
    output wire        is_nmp_add,
    output wire [4:0]  array_size,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7
);

    // Instruction format constants - Using dedicated NMP opcode
    localparam [6:0] OPCODE_NMP     = 7'b1101011;  // 0x6b - Dedicated NMP opcode
    localparam [2:0] FUNCT3_NMP_ADD = 3'b000;      // ADD operation
    localparam [2:0] FUNCT3_NMP_SUB = 3'b001;      // SUB operation (future)
    localparam [2:0] FUNCT3_NMP_MUL = 3'b010;      // MUL operation (future)
    localparam [2:0] FUNCT3_NMP_DIV = 3'b011;      // DIV operation (future)
    
    // Extract instruction fields
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign array_size = instruction[24:20];  // Size field in rs2 position
    assign funct7 = instruction[31:25];
    
    // Decode NMP_ADD instruction
    // Now we only need to check opcode (0x6b) and funct3 (000 for ADD)
    // No need to check funct7 anymore!
    assign is_nmp_add = instruction_valid && 
                       (opcode == OPCODE_NMP) && 
                       (funct3 == FUNCT3_NMP_ADD);

endmodule
