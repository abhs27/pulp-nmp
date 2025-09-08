# PULPino Instruction Definition and Extension Guide for Near Memory Processing (NMP) Integration

## Table of Contents
1. [Overview](#overview)
2. [PULPino Architecture](#pulpino-architecture)
3. [Instruction Definition Structure](#instruction-definition-structure)
4. [Current Instruction Support](#current-instruction-support)
5. [Adding New Instructions](#adding-new-instructions)
6. [Near Memory Processing Integration Strategy](#near-memory-processing-integration-strategy)
7. [Step-by-Step Implementation Guide](#step-by-step-implementation-guide)
8. [Files to Modify](#files-to-modify)
9. [Testing and Validation](#testing-and-validation)
10. [References](#references)

## Overview

PULPino is an open-source single-core microcontroller system based on 32-bit RISC-V cores developed at ETH Zurich. It supports two core variants:
- **RI5CY**: A 4-stage pipeline core with extensive custom instruction extensions
- **Zero-RISCY**: A 2-stage pipeline core focused on ultra-low power consumption

This document provides a comprehensive guide for understanding how instructions are defined in PULPino and how to add new instructions specifically for Near Memory Processing (NMP) units integration.

## PULPino Architecture

### Core Selection
The processor core selection is controlled by the `USE_ZERO_RISCY` parameter in the top-level design:
- `USE_ZERO_RISCY = 0`: Uses RI5CY core (supports custom PULP extensions)
- `USE_ZERO_RISCY = 1`: Uses Zero-RISCY core (minimal RISC-V implementation)

### Key Architectural Components
```
pulpino_top.sv
├── core_region.sv
│   ├── riscv_core.sv (RI5CY) OR zeroriscy_core.sv (Zero-RISCY)
│   │   ├── riscv_decoder.sv / zeroriscy_decoder.sv
│   │   ├── riscv_alu.sv / zeroriscy_alu.sv
│   │   ├── riscv_ex_stage.sv / zeroriscy_ex_block.sv
│   │   └── riscv_id_stage.sv / zeroriscy_id_stage.sv
│   ├── Data RAM (for NMP integration)
│   └── Instruction RAM
└── Peripherals
```

## Instruction Definition Structure

### 1. Opcode Definition
Instructions are identified by their 7-bit opcode in bits [6:0] of the instruction word.

**Location**: `/ips/riscv/include/riscv_defines.sv` and `/ips/zero-riscy/include/zeroriscy_defines.sv`

```systemverilog
// Standard RISC-V Opcodes
parameter OPCODE_OP        = 7'h33;  // R-type ALU operations
parameter OPCODE_OPIMM     = 7'h13;  // I-type ALU operations  
parameter OPCODE_LOAD      = 7'h03;  // Load instructions
parameter OPCODE_STORE     = 7'h23;  // Store instructions

// PULP Custom Opcodes (RI5CY only)
parameter OPCODE_PULP_OP   = 7'h5b;  // PULP-specific ALU instructions
parameter OPCODE_VECOP     = 7'h57;  // Vector operations
parameter OPCODE_HWLOOP    = 7'h7b;  // Hardware loops
parameter OPCODE_LOAD_POST = 7'h0b;  // Post-increment loads
parameter OPCODE_STORE_POST= 7'h2b;  // Post-increment stores
```

### 2. ALU Operation Encoding
ALU operations are defined with 7-bit codes:

```systemverilog
parameter ALU_OP_WIDTH = 7;

// Basic Operations
parameter ALU_ADD   = 7'b0011000;
parameter ALU_SUB   = 7'b0011001;
parameter ALU_XOR   = 7'b0101111;
parameter ALU_OR    = 7'b0101110;
parameter ALU_AND   = 7'b0010101;

// PULP Custom Operations
parameter ALU_CLIP  = 7'b0010110;  // Clipping
parameter ALU_ABS   = 7'b0010100;  // Absolute value
parameter ALU_MIN   = 7'b0010000;  // Minimum
parameter ALU_MAX   = 7'b0010010;  // Maximum
```

### 3. Instruction Decoding Process

The instruction decoder (`riscv_decoder.sv` or `zeroriscy_decoder.sv`) contains the main decoding logic:

```systemverilog
unique case (instr_rdata_i[6:0])
  OPCODE_OP: begin
    // Decode R-type ALU operations
    // Set control signals for execution
  end
  
  OPCODE_PULP_OP: begin
    // Decode PULP-specific operations
    // Handle 3-operand instructions
  end
  
  // Add new opcodes here for NMP instructions
  OPCODE_NMP_OP: begin
    // NMP instruction decoding logic
  end
endcase
```

## Current Instruction Support

### RI5CY Core Extensions
1. **Hardware Loops**: Zero-overhead loops with dedicated registers
2. **SIMD Operations**: Packed arithmetic on 16-bit and 8-bit data
3. **Bit Manipulation**: Extract, insert, bit counting operations
4. **MAC Operations**: Multiply-accumulate with rounding
5. **Post-increment Load/Store**: Memory access with auto-increment
6. **Fixed-point Operations**: Arithmetic with saturation and rounding

### Available Custom Opcodes
Based on RISC-V specification, these opcodes are available for custom extensions:
- `7'h0b` - Currently used for OPCODE_LOAD_POST
- `7'h2b` - Currently used for OPCODE_STORE_POST  
- `7'h5b` - Currently used for OPCODE_PULP_OP
- `7'h57` - Currently used for OPCODE_VECOP
- `7'h7b` - Currently used for OPCODE_HWLOOP

## Adding New Instructions

### Strategy for NMP Instructions
For Near Memory Processing integration, we recommend using a dedicated opcode space:

```systemverilog
// Proposed NMP opcode (using custom space)
parameter OPCODE_NMP_OP = 7'h6b;  // New opcode for NMP instructions
```

### NMP Instruction Format
We suggest using R-type format for NMP instructions:

```
31    25 24   20 19   15 14  12 11    7 6     0
+-------+-------+-------+-----+-------+-------+
| funct7| rs2   | rs1   |funct3| rd   |opcode |
+-------+-------+-------+-----+-------+-------+
   7       5       5      3      5       7
```

Where:
- `opcode[6:0] = 7'h6b` (OPCODE_NMP_OP)
- `funct3[2:0]` = NMP operation type
- `funct7[6:0]` = NMP unit selection and sub-operation
- `rs1, rs2` = Source operands
- `rd` = Destination register

## Key Files for Instruction Extension

### Hardware Files to Modify:
1. **`ips/riscv/include/riscv_defines.sv`** - Add NMP opcodes and ALU operations
2. **`ips/riscv/riscv_decoder.sv`** - Add NMP instruction decoding logic
3. **`ips/riscv/riscv_alu.sv`** - Add NMP ALU operation handling
4. **`ips/riscv/riscv_ex_stage.sv`** - Integrate NMP execution logic
5. **`rtl/core_region.sv`** - Add NMP unit instantiation and connections

### Software Files to Create:
1. **`sw/libs/sys_lib/inc/nmp_intrinsics.h`** - NMP intrinsic functions
2. **`sw/libs/sys_lib/src/nmp_lib.c`** - NMP library implementations

## Implementation Steps Summary

### Step 1: Define NMP Opcodes
Add to `ips/riscv/include/riscv_defines.sv`:
```systemverilog
parameter OPCODE_NMP_OP = 7'h6b;
parameter ALU_NMP_SEARCH  = 7'b1100000;  // Memory search operation
parameter ALU_NMP_SORT    = 7'b1100001;  // In-memory sort
parameter ALU_NMP_REDUCE  = 7'b1100010;  // Reduction operation
```

### Step 2: Extend Decoder
Add to `ips/riscv/riscv_decoder.sv`:
```systemverilog
OPCODE_NMP_OP: begin
  regfile_alu_we = 1'b1;      // Write result to register file
  rega_used_o    = 1'b1;      // Use rs1
  regb_used_o    = 1'b1;      // Use rs2
  
  unique case (instr_rdata_i[14:12])  // funct3
    3'b000: alu_operator_o = ALU_NMP_SEARCH;
    3'b001: alu_operator_o = ALU_NMP_SORT;
    3'b010: alu_operator_o = ALU_NMP_REDUCE;
    default: illegal_insn_o = 1'b1;
  endcase
end
```

### Step 3: Extend ALU
Add to `ips/riscv/riscv_alu.sv`:
```systemverilog
ALU_NMP_SEARCH,
ALU_NMP_SORT,
ALU_NMP_REDUCE: begin
  // NMP operations handled by dedicated units
  result_o = operand_a_i;  // Pass through base address
  ready_o  = nmp_ready_i;  // Wait for NMP unit completion
end
```

### Step 4: Create NMP Units
Create new directory `rtl/nmp_units/` and implement NMP controllers and processing units.

### Step 5: Software Support
Create intrinsics for software access:
```c
static inline int nmp_search(int *base_addr, int search_value) {
  int result;
  asm volatile ("nmp.search %0, %1, %2" 
                : "=r" (result) 
                : "r" (base_addr), "r" (search_value));
  return result;
}
```

## Memory Integration Strategy

### 1. NMP Unit Interface
Design NMP units as coprocessors connected to the data memory interface:
- Request/Grant handshaking
- Memory address and data buses
- Operation type encoding
- Multi-cycle operation support

### 2. Integration Points
- **Memory Controller**: Route NMP requests to appropriate units
- **Load-Store Unit**: Generate NMP requests from core
- **Execution Stage**: Handle NMP instruction execution

## Testing Approach

### 1. Unit Testing
- Dedicated testbenches for each NMP unit
- Memory access pattern verification
- Corner case testing

### 2. Integration Testing
- Full system testing with NMP instructions
- Performance benchmarking
- Interaction with standard RISC-V instructions

### 3. Software Testing
- Test applications using NMP intrinsics
- Compiler integration verification
- Various data size testing

## Implementation Checklist

- [ ] Define NMP opcodes in `riscv_defines.sv`
- [ ] Add NMP instruction decoding in `riscv_decoder.sv`
- [ ] Extend ALU with NMP operation handling
- [ ] Create NMP unit controller and processing units
- [ ] Integrate NMP units in `core_region.sv`
- [ ] Add memory arbitration logic for NMP access
- [ ] Create software intrinsics and library functions
- [ ] Develop comprehensive test suite
- [ ] Update build scripts and makefiles
- [ ] Create documentation and examples

## Important Notes

1. **Core Selection**: This implementation focuses on the RI5CY core for maximum extensibility
2. **Memory Bandwidth**: Critical for NMP performance - consider arbitration
3. **Power Management**: Consider power gating for unused NMP units
4. **RISC-V Compliance**: Ensure compliance with custom extension guidelines
5. **Pipeline Integration**: Handle multi-cycle NMP operations properly

## References

1. **RISC-V Specification**: https://riscv.org/specifications/
2. **PULPino Documentation**: Located in `doc/datasheet/` directory
3. **RI5CY Core Manual**: Available in PULP platform documentation
4. **RISC-V Custom Extensions Guide**: RISC-V International specification

