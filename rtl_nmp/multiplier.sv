// ========================================
// CSA (Carry-Save Adder) - 3:2 Compressor
// ========================================
module csa #(
    parameter WIDTH = 66
)(
    input  signed [WIDTH-1:0] a, b, d,
    output signed [WIDTH-1:0] sum, carry
);
    assign sum   = a ^ b ^ d;
    assign carry = ((a & b) | (a & d) | (b & d)) << 1;
endmodule

// ========================================
// Pipelined Booth-Encoded Wallace-Tree FMA
// 32-bit signed integer, 4-stage pipeline
// ========================================
module multiplier (
    input  wire        clk,
    input  wire        rst,
    input  signed [31:0] a,
    input  signed [31:0] b,
    input  signed [63:0] c,
    output signed [63:0] result
);

    // -------------------------------
    // Stage 1: Input Registers + Booth Encoding
    // -------------------------------
    reg signed [31:0] a_reg1;
    reg signed [31:0] b_reg1;
    reg signed [63:0] c_reg1;

    always @(posedge clk) begin
        if (rst) begin
            a_reg1 <= 32'sh0;
            b_reg1 <= 32'sh0;
            c_reg1 <= 64'sh0;
        end else begin
            a_reg1 <= a;
            b_reg1 <= b;
            c_reg1 <= c;
        end
    end

    // Booth Partial Products Generation (Radix-4, 16 PPs)
    wire signed [65:0] pp [0:15];

    genvar gen_i;
    generate
        for (gen_i = 0; gen_i < 16; gen_i = gen_i + 1) begin : booth_gen
            // Break out ternary to avoid width issues in concatenation
            wire prev_bit = (gen_i == 0) ? 1'b0 : b_reg1[2*gen_i - 1];
            wire curr_bit = b_reg1[2*gen_i];
            wire next_bit = (2*gen_i + 1 < 32) ? b_reg1[2*gen_i + 1] : b_reg1[31];
            wire [2:0] booth_bits = {next_bit, curr_bit, prev_bit};

            reg signed [33:0] mult;
            always @(*) begin
                case (booth_bits)
                    3'b001, 3'b010: mult = {{2{a_reg1[31]}}, a_reg1}; // +A
                    3'b011:        mult = a_reg1 << 1;             // +2A
                    3'b100:        mult = -(a_reg1 << 1);            // -2A
                    3'b101, 3'b110: mult = -{{2{a_reg1[31]}}, a_reg1}; // -A
                    default:       mult = 34'sh0;
                endcase
            end
            assign pp[gen_i] = {{32{mult[33]}}, mult} << (2 * gen_i);
        end
    endgenerate

    // -------------------------------
    // Pipeline Register 1: After Booth Generation
    // -------------------------------
    reg signed [65:0] pp_reg1 [0:15];
    reg signed [65:0] c_reg2;

    integer reg_idx;
    always @(posedge clk) begin
        if (rst) begin
            for (reg_idx = 0; reg_idx < 16; reg_idx = reg_idx + 1) begin
                pp_reg1[reg_idx] <= 66'sh0;
            end
            c_reg2 <= 66'sh0;
        end else begin
            for (reg_idx = 0; reg_idx < 16; reg_idx = reg_idx + 1) begin
                pp_reg1[reg_idx] <= pp[reg_idx];
            end
            c_reg2 <= {{2{c_reg1[63]}}, c_reg1};  // Sign-extend to 66 bits
        end
    end

    // -------------------------------
    // Stage 2: Wallace Tree Reduction Part 1 (17 operands -> 6)
    // -------------------------------
    // Level 1: Compress groups of 3 (5 CSAs + 2 pass-through)
    wire signed [65:0] level1_sum  [0:4];
    wire signed [65:0] level1_carry [0:4];
    wire signed [65:0] level1_pass  [0:1];

    csa #(66) csa_l1_0 (.a(pp_reg1[ 0]), .b(pp_reg1[ 1]), .d(pp_reg1[ 2]), .sum(level1_sum[0]), .carry(level1_carry[0]));
    csa #(66) csa_l1_1 (.a(pp_reg1[ 3]), .b(pp_reg1[ 4]), .d(pp_reg1[ 5]), .sum(level1_sum[1]), .carry(level1_carry[1]));
    csa #(66) csa_l1_2 (.a(pp_reg1[ 6]), .b(pp_reg1[ 7]), .d(pp_reg1[ 8]), .sum(level1_sum[2]), .carry(level1_carry[2]));
    csa #(66) csa_l1_3 (.a(pp_reg1[ 9]), .b(pp_reg1[10]), .d(pp_reg1[11]), .sum(level1_sum[3]), .carry(level1_carry[3]));
    csa #(66) csa_l1_4 (.a(pp_reg1[12]), .b(pp_reg1[13]), .d(pp_reg1[14]), .sum(level1_sum[4]), .carry(level1_carry[4]));
    assign level1_pass[0] = pp_reg1[15];
    assign level1_pass[1] = c_reg2;

    // Level 2: Compress to 8 operands
    wire signed [65:0] level2_sum  [0:3];
    wire signed [65:0] level2_carry [0:3];

    csa #(66) csa_l2_0 (.a(level1_sum[0]), .b(level1_sum[1]), .d(level1_sum[2]), .sum(level2_sum[0]), .carry(level2_carry[0]));
    csa #(66) csa_l2_1 (.a(level1_sum[3]), .b(level1_sum[4]), .d(level1_carry[0]), .sum(level2_sum[1]), .carry(level2_carry[1]));
    csa #(66) csa_l2_2 (.a(level1_carry[1]), .b(level1_carry[2]), .d(level1_carry[3]), .sum(level2_sum[2]), .carry(level2_carry[2]));
    csa #(66) csa_l2_3 (.a(level1_carry[4]), .b(level1_pass[0]), .d(level1_pass[1]), .sum(level2_sum[3]), .carry(level2_carry[3]));

    // Level 3: Compress to 6 operands
    wire signed [65:0] level3_sum  [0:1];
    wire signed [65:0] level3_carry [0:1];
    wire signed [65:0] level3_pass  [0:1];

    csa #(66) csa_l3_0 (.a(level2_sum[0]), .b(level2_sum[1]), .d(level2_sum[2]), .sum(level3_sum[0]), .carry(level3_carry[0]));
    csa #(66) csa_l3_1 (.a(level2_sum[3]), .b(level2_carry[0]), .d(level2_carry[1]), .sum(level3_sum[1]), .carry(level3_carry[1]));
    assign level3_pass[0] = level2_carry[2];
    assign level3_pass[1] = level2_carry[3];

    // -------------------------------
    // Pipeline Register 2: Mid-Reduction (6 operands)
    // -------------------------------
    reg signed [65:0] mid_reg [0:5];

    always @(posedge clk) begin
        if (rst) begin
            for (reg_idx = 0; reg_idx < 6; reg_idx = reg_idx + 1) begin
                mid_reg[reg_idx] <= 66'sh0;
            end
        end else begin
            mid_reg[0] <= level3_sum[0];
            mid_reg[1] <= level3_sum[1];
            mid_reg[2] <= level3_carry[0];
            mid_reg[3] <= level3_carry[1];
            mid_reg[4] <= level3_pass[0];
            mid_reg[5] <= level3_pass[1];
        end
    end

    // -------------------------------
    // Stage 3: Wallace Tree Reduction Part 2 (6 operands -> 2) + Final Adder
    // -------------------------------
    // Level 4: Compress to 4 operands
    wire signed [65:0] level4_sum  [0:1];
    wire signed [65:0] level4_carry [0:1];

    csa #(66) csa_l4_0 (.a(mid_reg[0]), .b(mid_reg[1]), .d(mid_reg[2]), .sum(level4_sum[0]), .carry(level4_carry[0]));
    csa #(66) csa_l4_1 (.a(mid_reg[3]), .b(mid_reg[4]), .d(mid_reg[5]), .sum(level4_sum[1]), .carry(level4_carry[1]));

    // Level 5: Compress to 3 operands
    wire signed [65:0] level5_sum;
    wire signed [65:0] level5_carry;
    wire signed [65:0] level5_pass;

    csa #(66) csa_l5_0 (.a(level4_sum[0]), .b(level4_sum[1]), .d(level4_carry[0]), .sum(level5_sum), .carry(level5_carry));
    assign level5_pass = level4_carry[1];

    // Level 6: Compress to 2 operands
    wire signed [65:0] level6_sum;
    wire signed [65:0] level6_carry;

    csa #(66) csa_l6_0 (.a(level5_sum), .b(level5_carry), .d(level5_pass), .sum(level6_sum), .carry(level6_carry));

    // Final Carry-Propagate Adder (synthesizes to CLA)
    wire signed [65:0] pre_result = level6_sum + level6_carry;

    // -------------------------------
    // Pipeline Register 3: Final Output
    // -------------------------------
    reg signed [63:0] result_reg;

    always @(posedge clk) begin
        if (rst) begin
            result_reg <= 64'sh0;
        end else begin
            result_reg <= pre_result[63:0];  // Truncate extra sign bits
        end
    end

    assign result = result_reg;

endmodule