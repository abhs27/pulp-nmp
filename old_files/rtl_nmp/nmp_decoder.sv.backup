//-----------------------------------------------------------------------------
// Title         : NMP Instruction Decoder
// Project       : PULPino NMP Extension
// Description   : Decodes custom NMP instructions
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

    // Instruction format constants
    localparam [6:0] OPCODE_RTYPE   = 7'b0110011;
    localparam [2:0] FUNCT3_NMP_ADD = 3'b000;
    localparam [6:0] FUNCT7_NMP_ADD = 7'b0110000;
    
    // Extract instruction fields
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign array_size = instruction[24:20];  // Size field in rs2 position
    assign funct7 = instruction[31:25];
    
    // Decode NMP_ADD instruction
    assign is_nmp_add = instruction_valid && 
                       (opcode == OPCODE_RTYPE) && 
                       (funct3 == FUNCT3_NMP_ADD) && 
                       (funct7 == FUNCT7_NMP_ADD);

endmodule
