# NMP Instruction Decoding - Complete Examples and Verification

## DECODER BIT-LEVEL BREAKDOWN EXAMPLES

### Example 1: Search for Value 0x1234 in Array at Address 0x10000000

**Assembly**: `nmp.search x8, x10, x12`
- x10 contains base address (0x10000000) 
- x12 contains search value (0x1234)
- x8 will receive result index (or -1 if not found)

**Manual Encoding**:
```
Field      | Value      | Binary    | Bit Range
-----------|------------|-----------|----------
opcode     | 7'h6b      | 1101011   | [6:0]
rd         | 5'd8 (x8)  | 01000     | [11:7] 
funct3     | NMP_SEARCH | 000       | [14:12]
rs1        | 5'd10(x10) | 01010     | [19:15]
rs2        | 5'd12(x12) | 01100     | [24:20]
funct7     | 7'b0000000 | 0000000   | [31:25]
```

**Complete 32-bit Instruction**:
```
31    25 24   20 19   15 14  12 11    7 6     0
0000000  01100  01010  000   01000  1101011
```
**Hex**: 0x00C5046B

**Decoder Process Step-by-Step**:
1. `instr_rdata_i[6:0]` = 7'h6b → Matches OPCODE_NMP_OP ✓
2. Enter OPCODE_NMP_OP case in decoder
3. `instr_rdata_i[14:12]` = 3'b000 → Matches NMP_SEARCH ✓
4. Set `alu_operator_o = ALU_NMP_SEARCH` (7'b1100000)
5. Set `rega_used_o = 1'b1` (use rs1 = x10)
6. Set `regb_used_o = 1'b1` (use rs2 = x12) 
7. Set `regfile_alu_we = 1'b1` (write result to rd = x8)
8. Extract funct7 = 7'b0000000 (default search config)

### Example 2: Sort Array in Descending Order

**Assembly**: `nmp.sort x15, x20, x25` 
- x20 contains array base address
- x25 contains array size 
- x15 will receive status/result
- funct7 = 7'b0000001 (descending order flag)

**Manual Encoding**:
```
Field      | Value       | Binary    | Bit Range
-----------|-------------|-----------|----------
opcode     | 7'h6b       | 1101011   | [6:0]
rd         | 5'd15 (x15) | 01111     | [11:7]
funct3     | NMP_SORT    | 001       | [14:12]
rs1        | 5'd20 (x20) | 10100     | [19:15]
rs2        | 5'd25 (x25) | 11001     | [24:20]  
funct7     | 7'b0000001  | 0000001   | [31:25]
```

**Complete 32-bit Instruction**:
```
31    25 24   20 19   15 14  12 11    7 6     0
0000001  11001  10100  001   01111  1101011
```
**Hex**: 0x03A9478B

**Decoder Process**:
1. `instr_rdata_i[6:0]` = 7'h6b → OPCODE_NMP_OP ✓
2. `instr_rdata_i[14:12]` = 3'b001 → NMP_SORT ✓
3. Set `alu_operator_o = ALU_NMP_SORT` (7'b1100001)
4. `instr_rdata_i[19:15]` = 5'd20 → rs1 = x20 (array base)
5. `instr_rdata_i[24:20]` = 5'd25 → rs2 = x25 (array size)
6. `instr_rdata_i[11:7]` = 5'd15 → rd = x15 (result)
7. `instr_rdata_i[31:25]` = 7'b0000001 → Descending sort config

### Example 3: Reduce (SUM) Operation

**Assembly**: `nmp.reduce x5, x18, x23`
- x18 = array base address
- x23 = array size
- x5 = result (sum of all elements)
- funct7 = 7'b0010000 (SUM operation code)

**Manual Encoding**:
```  
Field      | Value       | Binary    | Bit Range
-----------|-------------|-----------|----------
opcode     | 7'h6b       | 1101011   | [6:0]
rd         | 5'd5 (x5)   | 00101     | [11:7]
funct3     | NMP_REDUCE  | 010       | [14:12]
rs1        | 5'd18 (x18) | 10010     | [19:15]
rs2        | 5'd23 (x23) | 10111     | [24:20]
funct7     | 7'b0010000  | 0010000   | [31:25]
```

**Complete 32-bit Instruction**:
```
31    25 24   20 19   15 14  12 11    7 6     0
0010000  10111  10010  010   00101  1101011
```
**Hex**: 0x20B9256B

**Decoder Process**:
1. `instr_rdata_i[6:0]` = 7'h6b → OPCODE_NMP_OP ✓
2. `instr_rdata_i[14:12]` = 3'b010 → NMP_REDUCE ✓  
3. Set `alu_operator_o = ALU_NMP_REDUCE` (7'b1100010)
4. Extract configuration: funct7 = 7'b0010000 → SUM operation

## VERIFICATION CHECKLIST

To verify the decoder is working correctly, check these conditions:

### 1. Opcode Recognition Test
```systemverilog
// Test vector: Any NMP instruction
wire [31:0] test_instr = 32'h00C5046B; // NMP.SEARCH example
wire [6:0] extracted_opcode = test_instr[6:0];

assert(extracted_opcode == OPCODE_NMP_OP) // Should be 7'h6b
```

### 2. Operation Decode Test  
```systemverilog
// Test all 5 NMP operations
wire [2:0] funct3_search = 3'b000;
wire [2:0] funct3_sort   = 3'b001; 
wire [2:0] funct3_reduce = 3'b010;
wire [2:0] funct3_filter = 3'b011;
wire [2:0] funct3_map    = 3'b100;

// Verify mapping to ALU operations
assert(funct3_search maps to ALU_NMP_SEARCH);
assert(funct3_sort   maps to ALU_NMP_SORT);
// ... etc
```

### 3. Register Field Extraction Test
```systemverilog
wire [31:0] test_instr = 32'h00C5046B; // NMP.SEARCH x8, x10, x12

wire [4:0] rd  = test_instr[11:7];   // Should be 5'd8
wire [4:0] rs1 = test_instr[19:15];  // Should be 5'd10  
wire [4:0] rs2 = test_instr[24:20];  // Should be 5'd12
wire [6:0] funct7 = test_instr[31:25]; // Should be 7'b0000000

assert(rd == 5'd8);
assert(rs1 == 5'd10);
assert(rs2 == 5'd12);
```

### 4. Control Signal Generation Test
```systemverilog
// When decoding NMP instruction, verify:
assert(rega_used_o == 1'b1);      // rs1 is used
assert(regb_used_o == 1'b1);      // rs2 is used  
assert(regfile_alu_we == 1'b1);   // Result written to rd
assert(instr_multicycle_o == 1'b1); // NMP ops are multi-cycle
```

## COMMON DECODING ERRORS TO AVOID

1. **Wrong Bit Ranges**: Ensure correct bit field extraction
   - Opcode: [6:0] (7 bits)
   - rd: [11:7] (5 bits)
   - funct3: [14:12] (3 bits)
   - rs1: [19:15] (5 bits)  
   - rs2: [24:20] (5 bits)
   - funct7: [31:25] (7 bits)

2. **Missing Control Signals**: Must set all required control flags
3. **Invalid Operation Handling**: Must detect illegal funct3 values
4. **Multi-cycle Flag**: NMP operations require multiple cycles

## CURRENT IMPLEMENTATION STATUS

❌ **CRITICAL**: The decoder case for OPCODE_NMP_OP is MISSING from riscv_decoder.sv
❌ **RESULT**: ALL NMP instructions currently trigger illegal instruction exceptions
✅ **SOLUTION**: Add the code from NMP_DECODER_IMPLEMENTATION.sv to riscv_decoder.sv

## INTEGRATION VERIFICATION STEPS

After adding decoder support:

1. **Compile Test**: Verify SystemVerilog compiles without errors
2. **Simulation Test**: Load NMP instruction and verify decoder outputs
3. **Pipeline Test**: Ensure decoded signals propagate through pipeline
4. **ALU Test**: Verify ALU receives and handles ALU_NMP_* operations
5. **End-to-End Test**: Full NMP instruction execution test
