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
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_op,
    // Outputs
    output reg [31:0] result,
    output wire        overflow,
    output wire        zero,
    output reg         op_done
);

    // ALU operation codes
    localparam [2:0] ALU_ADD = 3'b000;
    localparam [2:0] ALU_SUB = 3'b001;  // Future extension
    localparam [2:0] ALU_MUL = 3'b010;  // Future extension
    localparam [2:0] ALU_DIV = 3'b011;  // Future extension
    
    //Internal operand register
    reg [31:0] reg_operand_a, reg_operand_b;


    // Internal signals
    wire [32:0] add_result;
    wire [32:0] sub_result;
    wire [63:0] mul_result_wide;
    wire [31:0] div_result;

    // done signals
    wire div_done;
    reg [2:0] mul_latency_counter;


    // instantiate multiplier
    multiplier mul(
        .clk(clk),
        .rst(!rst_n), //reset for multiplier is active high
        .a(reg_operand_a),
        .b(reg_operand_b),
        .c(64'h0),
        .result(mul_result_wide)
    );


    // Instantiate divider

    divider u_div(
        .clk(clk), .rst_n(rst_n),
        .start(start_op && (operation == ALU_DIV)),
        .a(reg_operand_a), .b(reg_operand_b),
        .q(div_result), .done(div_done)
    );


    // Perform operations
    assign add_result = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_result = {1'b0, operand_a} - {1'b0, operand_b};
    
    // Select result based on operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            reg_operand_a <= 32'b0;
            reg_operand_b <= 32'b0; 
            op_done <= 1'b0;
            mul_latency_counter <= 3'b0;
            result <= 32'b0;
        end else begin 
            op_done <= 1'b0;

            if (start_op) begin
                reg_operand_a <= operand_a;
                reg_operand_b <= operand_b;
                mul_latency_counter <= 3'd4;
            end

            case (operation)
                ALU_ADD:begin
                    if(start_op) begin 
                        result <= add_result[31:0];
                        op_done <= 1'b1;
                    end
                end

                ALU_SUB:begin
                    if(start_op) begin 
                        result <= sub_result[31:0];
                        op_done <= 1'b1;
                    end
                end

                ALU_MUL: begin
                    if (mul_latency_counter != 3'b0) begin
                        mul_latency_counter <= mul_latency_counter - 1;
                        if (mul_latency_counter == 1) begin
                            result <= mul_result_wide[31:0]; // Lower 32 bits
                            op_done <= 1'b1;
                        end
                    end
                end

                ALU_DIV: begin
                    if (div_done) begin
                        result <= div_result;
                        op_done <= 1'b1;
                    end
                end
            
                default: ; // Do nothing for undefined operations
            endcase

        end
        
    end
    
    // Status flags
    assign overflow = (operation == ALU_ADD) ? add_result[32] : 
                     (operation == ALU_SUB) ? sub_result[32] : 1'b0;
    assign zero = (result == 32'b0);

endmodule
