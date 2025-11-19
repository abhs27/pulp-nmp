`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_decoder_hash
// Project       : PULPino NMP Extension
// Description   : Verifies the instruction decoder for all NMP operations.
//-----------------------------------------------------------------------------
module tb_nmp_decoder_hash;

    // DUT Interface
    reg  [31:0] instruction;
    reg         instruction_valid;
    reg         hash_mode_enable;

    wire        nmp_valid_start;
    wire [4:0]  array_size;
    wire [16:0] hash_index;
    wire        use_hash_mode;
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate the DUT
    nmp_decoder_hash dut (
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .hash_mode_enable(hash_mode_enable),
        .nmp_valid_start(nmp_valid_start),
        .array_size(array_size),
        .hash_index(hash_index),
        .use_hash_mode(use_hash_mode),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7)
    );

    // Helper function to construct an instruction
    function automatic [31:0] create_instruction(
        input [16:0] f_hash,
        input [2:0]  f_funct3,
        input [4:0]  f_size,
        input [6:0]  f_opcode
    );
        return {f_hash, f_funct3, f_size, f_opcode};
    endfunction

    // Task to run a single test
    task run_test;
        input [31:0] t_inst;
        input        t_inst_valid;
        input        t_hash_mode_en;
        input        exp_nmp_valid_start;
        input [4:0]  exp_array_size;
        input [16:0] exp_hash_index;
        input        exp_use_hash_mode;
        input [6:0]  exp_opcode;
        input [2:0]  exp_funct3;
        input string test_name;
        
        reg test_passed;
        begin
            test_count++;
            test_passed = 1'b1;

            // Apply inputs
            instruction = t_inst;
            instruction_valid = t_inst_valid;
            hash_mode_enable = t_hash_mode_en;

            #1; // Wait for combinational logic

            // Check all outputs
            if (nmp_valid_start !== exp_nmp_valid_start) begin test_passed = 0; $display("[FAIL] %s: nmp_valid_start mismatch. Exp: %b, Got: %b", test_name, exp_nmp_valid_start, nmp_valid_start); end
            if (array_size !== exp_array_size) begin test_passed = 0; $display("[FAIL] %s: array_size mismatch. Exp: %h, Got: %h", test_name, exp_array_size, array_size); end
            if (hash_index !== exp_hash_index) begin test_passed = 0; $display("[FAIL] %s: hash_index mismatch. Exp: %h, Got: %h", test_name, exp_hash_index, hash_index); end
            if (use_hash_mode !== exp_use_hash_mode) begin test_passed = 0; $display("[FAIL] %s: use_hash_mode mismatch. Exp: %b, Got: %b", test_name, exp_use_hash_mode, use_hash_mode); end
            if (opcode !== exp_opcode) begin test_passed = 0; $display("[FAIL] %s: opcode mismatch. Exp: %h, Got: %h", test_name, exp_opcode, opcode); end
            if (funct3 !== exp_funct3) begin test_passed = 0; $display("[FAIL] %s: funct3 mismatch. Exp: %h, Got: %h", test_name, exp_funct3, funct3); end

            if (test_passed) begin
                $display("[PASS] %s", test_name);
                pass_count++;
            end else begin
                fail_count++;
            end
        end
    endtask

    // Main test sequence
    initial begin
        // Constants for instruction parts
        localparam [6:0] NMP_OPCODE = 7'b1101011;
        localparam [6:0] OTHER_OPCODE = 7'b0000000;
        localparam [2:0] F3_ADD = 3'b000;
        localparam [2:0] F3_SUB = 3'b001;
        localparam [2:0] F3_MUL = 3'b010;
        localparam [2:0] F3_DIV = 3'b011;
        localparam [2:0] F3_INV = 3'b111; // Invalid funct3
        localparam [4:0] SIZE = 5'd16;
        localparam [16:0] HASH = 17'h1A2B3;

        $display("\n=========================================");
        $display("=== Testbench for nmp_decoder_hash ===");
        $display("=========================================\n");

        // --- Directed Tests ---
        $display("--- Running Directed Tests ---");

        // Valid operations
        run_test(create_instruction(HASH, F3_ADD, SIZE, NMP_OPCODE), 1'b1, 1'b1, 1'b1, SIZE, HASH, 1'b1, NMP_OPCODE, F3_ADD, "Valid ADD instruction");
        run_test(create_instruction(HASH, F3_SUB, SIZE, NMP_OPCODE), 1'b1, 1'b1, 1'b1, SIZE, HASH, 1'b1, NMP_OPCODE, F3_SUB, "Valid SUB instruction");
        run_test(create_instruction(HASH, F3_MUL, SIZE, NMP_OPCODE), 1'b1, 1'b1, 1'b1, SIZE, HASH, 1'b1, NMP_OPCODE, F3_MUL, "Valid MUL instruction");
        run_test(create_instruction(HASH, F3_DIV, SIZE, NMP_OPCODE), 1'b1, 1'b1, 1'b1, SIZE, HASH, 1'b1, NMP_OPCODE, F3_DIV, "Valid DIV instruction");

        // Invalid cases that should not start the NMP
        run_test(create_instruction(HASH, F3_ADD, SIZE, NMP_OPCODE), 1'b0, 1'b1, 1'b0, SIZE, HASH, 1'b1, NMP_OPCODE, F3_ADD, "Instruction Not Valid");
        run_test(create_instruction(HASH, F3_ADD, SIZE, OTHER_OPCODE), 1'b1, 1'b1, 1'b0, SIZE, HASH, 1'b1, OTHER_OPCODE, F3_ADD, "Wrong Opcode");
        run_test(create_instruction(HASH, F3_INV, SIZE, NMP_OPCODE), 1'b1, 1'b1, 1'b0, SIZE, HASH, 1'b1, NMP_OPCODE, F3_INV, "Invalid Funct3");

        // Test hash_mode_enable flag
        run_test(create_instruction(HASH, F3_ADD, SIZE, NMP_OPCODE), 1'b1, 1'b0, 1'b1, SIZE, HASH, 1'b0, NMP_OPCODE, F3_ADD, "Hash Mode Disabled");

        // Test field extraction
        run_test(create_instruction(17'h1FFFF, F3_ADD, 5'd31, NMP_OPCODE), 1'b1, 1'b1, 1'b1, 5'd31, 17'h1FFFF, 1'b1, NMP_OPCODE, F3_ADD, "Max Hash and Size");
        run_test(create_instruction(17'h00000, F3_ADD, 5'd1, NMP_OPCODE), 1'b1, 1'b1, 1'b1, 5'd1, 17'h00000, 1'b1, NMP_OPCODE, F3_ADD, "Min Hash and Size");

        // --- Test Summary ---
        $display("\n=========================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("=========================================\n");

        $finish;
    end

endmodule
