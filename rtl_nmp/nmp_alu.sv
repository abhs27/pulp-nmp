//-----------------------------------------------------------------------------
// Title         : NMP Arithmetic Logic Unit
// Project       : PULPino NMP Extension
// Description   : ALU for NMP operations (currently supports addition)
//-----------------------------------------------------------------------------

module nmp_alu (
    // Inputs
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [2:0]  operation,  // Future extension for other operations
    
    // Outputs
    output reg [31:0] result,
    output wire        overflow,
    output wire        zero
);

    // ALU operation codes
    localparam [2:0] ALU_ADD = 3'b000;
    localparam [2:0] ALU_SUB = 3'b001;  // Future extension
    localparam [2:0] ALU_MUL = 3'b010;  // Future extension
    
    // Internal signals
    wire [32:0] add_result;
    wire [32:0] sub_result;
    
    // Perform operations
    assign add_result = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_result = {1'b0, operand_a} - {1'b0, operand_b};
    
    // Select result based on operation
    always @(*) begin
        case (operation)
            ALU_ADD: result = add_result[31:0];
            ALU_SUB: result = sub_result[31:0];
            default: result = add_result[31:0];  // Default to addition
        endcase
    end
    
    // Status flags
    assign overflow = (operation == ALU_ADD) ? add_result[32] : 
                     (operation == ALU_SUB) ? sub_result[32] : 1'b0;
    assign zero = (result == 32'b0);

endmodule
