# Near Memory Processing (NMP) Unit - Integration Guide

## Table of Contents
1. [Overview](#overview)
2. [Block Diagram](#block-diagram)
3. [Pin Interface Description](#pin-interface-description)
4. [Integration Steps](#integration-steps)
5. [Timing Specifications](#timing-specifications)
6. [Programming Model](#programming-model)
7. [Example Usage](#example-usage)

---

## Overview

The Near Memory Processing (NMP) unit is a hardware accelerator designed to perform common memory-intensive operations directly near the memory subsystem, reducing data movement and improving performance for specific workloads.

### Key Features
- **5 Processing Units**: Search, Sort, Reduce, Filter, Map
- **32-bit RISC-V ISA Extension**: Custom opcode 0x6B
- **Configurable Data Types**: 8-bit, 16-bit, 32-bit support
- **Performance Monitoring**: Built-in cycle counters
- **Memory Arbitration**: Round-robin access control
- **Status Reporting**: Error detection and operation status

### Performance Targets (at 100MHz)
- Search: 100M comparisons/second
- Sort: 10K elements/second (max 64 elements)
- Reduce: 200M operations/second
- Filter: 150M elements/second
- Map: 100M transformations/second

---

## Block Diagram

```
                           PULPino Core (RISC-V)
                                    |
                    ┌───────────────┴───────────────┐
                    │          Core Interface       │
                    └───────────────┬───────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │                          NMP_TOP Module                       │
    │                                                                │
    │  ┌─────────────────────────────────────────────────────────┐  │
    │  │                   NMP Controller                        │  │
    │  │  ┌────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
    │  │  │   Decoder  │  │ State Machine│  │   Arbiter    │   │  │
    │  │  └────────────┘  └──────────────┘  └──────────────┘   │  │
    │  └─────────────────────────┬───────────────────────────────┘  │
    │                            │                                  │
    │        ┌───────────────────┼───────────────────┐             │
    │        │                   │                   │             │
    │   ┌────▼────┐  ┌──────────▼────┐  ┌──────────▼────┐        │
    │   │ Search   │  │     Sort      │  │    Reduce     │        │
    │   │  Unit    │  │     Unit      │  │     Unit      │        │
    │   │          │  │               │  │               │        │
    │   │ - Linear │  │ - Bubble Sort │  │ - SUM/PRODUCT │        │
    │   │ - Pattern│  │ - Ascending/  │  │ - MIN/MAX     │        │
    │   │   Match  │  │   Descending  │  │ - AND/OR/XOR  │        │
    │   └────┬────┘  └───────┬───────┘  └───────┬───────┘        │
    │        │                │                   │                │
    │   ┌────▼────────────────▼───────────────────▼────┐          │
    │   │          Memory Arbitration Unit             │          │
    │   └────┬─────────────────────────────────────┬───┘          │
    │        │                                     │               │
    │   ┌────▼────┐                      ┌────────▼────┐          │
    │   │ Filter   │                      │    Map      │          │
    │   │  Unit    │                      │    Unit     │          │
    │   │          │                      │             │          │
    │   │ - Range  │                      │ - Scale     │          │
    │   │ - Thresh │                      │ - Add/Square│          │
    │   │   old    │                      │ - Abs/Negate│          │
    │   └──────────┘                      └─────────────┘          │
    │                                                               │
    └───────────────────────────┬───────────────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │   Memory Interface     │
                    └───────────┬────────────┘
                                │
                         Memory Subsystem
```

---

## Pin Interface Description

### Top-Level Module: `nmp_top`

#### Input Pins

| Pin Name | Width | Direction | Description |
|----------|-------|-----------|-------------|
| `clk_i` | 1 | Input | System clock (100MHz typical) |
| `rst_ni` | 1 | Input | Active-low asynchronous reset |
| **Core Interface** | | | |
| `nmp_req_i` | 1 | Input | Request signal from processor core |
| `nmp_addr_i` | 32 | Input | Memory address for NMP operation |
| `nmp_wdata_i` | 32 | Input | Data/parameter for NMP operation |
| `nmp_we_i` | 1 | Input | Write enable (typically 0 for NMP ops) |
| `nmp_be_i` | 4 | Input | Byte enable mask |
| `nmp_op_i` | 3 | Input | NMP operation type (funct3 field) |
| `nmp_funct7_i` | 7 | Input | Operation parameters (funct7 field) |
| **Memory Interface** | | | |
| `mem_gnt_i` | 1 | Input | Memory grant signal |
| `mem_rdata_i` | 32 | Input | Read data from memory |
| `mem_valid_i` | 1 | Input | Memory response valid |
| `mem_error_i` | 1 | Input | Memory error signal |
| **Configuration** | | | |
| `nmp_enable_i` | 1 | Input | Enable NMP unit |
| `nmp_reset_i` | 1 | Input | Soft reset for NMP unit |

#### Output Pins

| Pin Name | Width | Direction | Description |
|----------|-------|-----------|-------------|
| **Core Interface** | | | |
| `nmp_gnt_o` | 1 | Output | Grant signal to processor core |
| `nmp_rdata_o` | 32 | Output | Read data to processor (unused) |
| `nmp_valid_o` | 1 | Output | Operation complete signal |
| `nmp_ready_o` | 1 | Output | Ready for new operation |
| `nmp_result_o` | 32 | Output | Operation result |
| `nmp_error_o` | 1 | Output | Error flag |
| `nmp_status_o` | 8 | Output | Detailed status code |
| `nmp_busy_o` | 1 | Output | NMP unit busy flag |
| **Memory Interface** | | | |
| `mem_req_o` | 1 | Output | Memory request |
| `mem_addr_o` | 32 | Output | Memory address |
| `mem_wdata_o` | 32 | Output | Write data to memory |
| `mem_we_o` | 1 | Output | Memory write enable |
| `mem_be_o` | 4 | Output | Memory byte enable |
| **Status/Debug** | | | |
| `nmp_perf_counter_o` | 32 | Output | Performance counter |
| `nmp_unit_status_o` | 8 | Output | Unit-specific status |
| `nmp_interrupt_o` | 1 | Output | Interrupt signal |

### Operation Encoding (nmp_op_i)

| nmp_op_i | Operation | Description |
|----------|-----------|-------------|
| 3'b000 | SEARCH | Memory search operation |
| 3'b001 | SORT | In-memory sorting |
| 3'b010 | REDUCE | Reduction operations |
| 3'b011 | FILTER | Data filtering |
| 3'b100 | MAP | Element transformations |

### Function Encoding (nmp_funct7_i)

The 7-bit `nmp_funct7_i` field encodes operation-specific parameters:

#### SEARCH Operation
- `funct7[6:5]`: Data width (00=8bit, 01=16bit, 10=32bit)
- `funct7[4:2]`: Reserved
- `funct7[1:0]`: Search mode (00=exact, 01=pattern)

#### SORT Operation
- `funct7[6]`: Order (0=ascending, 1=descending)
- `funct7[5:0]`: Element count (max 64)

#### REDUCE Operation
- `funct7[6:4]`: Operation type
  - 000: SUM
  - 001: PRODUCT
  - 010: MIN
  - 011: MAX
  - 100: AND
  - 101: OR
  - 110: XOR
- `funct7[3:0]`: Reserved

#### FILTER Operation
- `funct7[6:4]`: Filter type
  - 000: Equal
  - 001: Greater than
  - 010: Less than
  - 011: Range
- `funct7[3:0]`: Threshold/parameter

#### MAP Operation
- `funct7[6:4]`: Transform type
  - 000: SCALE
  - 001: ADD
  - 010: SQUARE
  - 011: ABS
  - 100: NEGATE
  - 101: SHIFT
- `funct7[3:0]`: Parameter value

---

## Integration Steps

### Step 1: Core Modifications

#### 1.1 Add NMP Opcode to RISC-V Defines
File: `pulpino/ips/riscv/include/riscv_defines.sv`
```systemverilog
// Add to opcode definitions
parameter OPCODE_NMP_OP = 7'h6b;

// Add to ALU operation codes
parameter ALU_NMP_SEARCH = 7'b1100000;
parameter ALU_NMP_SORT   = 7'b1100001;
parameter ALU_NMP_REDUCE = 7'b1100010;
parameter ALU_NMP_FILTER = 7'b1100011;
parameter ALU_NMP_MAP    = 7'b1100100;
```

#### 1.2 Update Instruction Decoder
File: `pulpino/ips/riscv/riscv_decoder.sv`
```systemverilog
// In decode stage, add NMP opcode handling
OPCODE_NMP_OP: begin
  alu_en         = 1'b1;
  rega_used_o    = 1'b1;
  regb_used_o    = 1'b1;
  regfile_we     = 1'b1;
  
  case (instr_rdata_i[14:12]) // funct3
    3'b000: alu_operator_o = ALU_NMP_SEARCH;
    3'b001: alu_operator_o = ALU_NMP_SORT;
    3'b010: alu_operator_o = ALU_NMP_REDUCE;
    3'b011: alu_operator_o = ALU_NMP_FILTER;
    3'b100: alu_operator_o = ALU_NMP_MAP;
    default: illegal_insn_o = 1'b1;
  endcase
end
```

#### 1.3 Instantiate NMP in Core Region
File: `pulpino/rtl/core_region.sv`
```systemverilog
// Add NMP signals
logic        nmp_req;
logic        nmp_gnt;
logic [31:0] nmp_result;
logic        nmp_valid;
logic        nmp_busy;

// Instantiate NMP top module
nmp_top nmp_top_i (
  .clk_i              (clk),
  .rst_ni             (rst_n),
  
  // Core interface
  .nmp_req_i          (nmp_req),
  .nmp_gnt_o          (nmp_gnt),
  .nmp_addr_i         (alu_operand_a),
  .nmp_wdata_i        (alu_operand_b),
  .nmp_we_i           (1'b0),
  .nmp_be_i           (4'hF),
  .nmp_op_i           (instr[14:12]),
  .nmp_funct7_i       (instr[31:25]),
  .nmp_valid_o        (nmp_valid),
  .nmp_ready_o        (nmp_ready),
  .nmp_result_o       (nmp_result),
  .nmp_error_o        (nmp_error),
  .nmp_status_o       (nmp_status),
  .nmp_busy_o         (nmp_busy),
  
  // Memory interface (connect to arbiter)
  .mem_req_o          (nmp_mem_req),
  .mem_gnt_i          (nmp_mem_gnt),
  .mem_addr_o         (nmp_mem_addr),
  .mem_wdata_o        (nmp_mem_wdata),
  .mem_rdata_i        (nmp_mem_rdata),
  .mem_we_o           (nmp_mem_we),
  .mem_be_o           (nmp_mem_be),
  .mem_valid_i        (nmp_mem_valid),
  .mem_error_i        (nmp_mem_error),
  
  // Configuration
  .nmp_enable_i       (1'b1),
  .nmp_reset_i        (1'b0),
  .nmp_perf_counter_o (nmp_perf_counter),
  .nmp_unit_status_o  (nmp_unit_status),
  .nmp_interrupt_o    (nmp_interrupt)
);
```

### Step 2: Memory Arbitration

Create or modify memory arbiter to handle both core and NMP requests:

```systemverilog
// Simple round-robin arbiter example
always_ff @(posedge clk) begin
  if (!rst_n) begin
    grant_to_nmp <= 1'b0;
  end else begin
    if (core_mem_req && nmp_mem_req) begin
      grant_to_nmp <= ~grant_to_nmp; // Alternate
    end else if (nmp_mem_req) begin
      grant_to_nmp <= 1'b1;
    end else begin
      grant_to_nmp <= 1'b0;
    end
  end
end
```

### Step 3: Build System Updates

#### 3.1 Add to Synthesis File List
File: `pulpino/syn/synopsys/scripts/analyze.tcl`
```tcl
# Add NMP files
analyze -format sverilog -lib WORK $RTL/nmp_units/include/nmp_if.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/include/nmp_mem_if.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_controller.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_controller_fsm.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_search_unit.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_sort_unit.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_reduce_unit.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_filter_unit.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_map_unit.sv
analyze -format sverilog -lib WORK $RTL/nmp_units/nmp_top.sv
```

#### 3.2 Add to Simulation File List
File: `pulpino/vsim/tcl_files/config/vsim.tcl`
```tcl
# Add NMP sources
set RTL_NMP " \
  $RTL/nmp_units/include/nmp_if.sv \
  $RTL/nmp_units/include/nmp_mem_if.sv \
  $RTL/nmp_units/nmp_controller.sv \
  $RTL/nmp_units/nmp_controller_fsm.sv \
  $RTL/nmp_units/nmp_search_unit.sv \
  $RTL/nmp_units/nmp_sort_unit.sv \
  $RTL/nmp_units/nmp_reduce_unit.sv \
  $RTL/nmp_units/nmp_filter_unit.sv \
  $RTL/nmp_units/nmp_map_unit.sv \
  $RTL/nmp_units/nmp_top.sv \
"
```

---

## Timing Specifications

### Clock Requirements
- **Frequency**: 50-200 MHz (100 MHz typical)
- **Duty Cycle**: 50% ± 5%
- **Clock Jitter**: < 100ps

### Interface Timing
| Parameter | Min | Typical | Max | Unit |
|-----------|-----|---------|-----|------|
| Setup time (inputs) | 2 | - | - | ns |
| Hold time (inputs) | 0.5 | - | - | ns |
| Clock-to-output | - | 3 | 5 | ns |
| Request to grant | 1 | 2 | 4 | cycles |
| Operation latency (Search) | 10 | 50 | 1000 | cycles |
| Operation latency (Sort) | 100 | 500 | 5000 | cycles |
| Operation latency (Reduce) | 10 | 50 | 500 | cycles |
| Operation latency (Filter) | 10 | 50 | 500 | cycles |
| Operation latency (Map) | 10 | 50 | 500 | cycles |

---

## Programming Model

### Assembly Instruction Format

NMP instructions follow R-type format:
```
| funct7 (7) | rs2 (5) | rs1 (5) | funct3 (3) | rd (5) | opcode (7) |
| parameters | src2    | src1    | operation  | dest  | 0x6B       |
```

### Assembly Syntax
```assembly
# Search for value in rs2 starting at address in rs1
nmp.search rd, rs1, rs2, funct7

# Sort array at address rs1 with count in rs2
nmp.sort rd, rs1, rs2, funct7

# Reduce array at rs1 with count in rs2
nmp.reduce rd, rs1, rs2, funct7

# Filter array at rs1 with threshold in rs2
nmp.filter rd, rs1, rs2, funct7

# Map transformation on array at rs1 with parameter in rs2
nmp.map rd, rs1, rs2, funct7
```

### C Intrinsics
```c
// Search operation
uint32_t nmp_search(void* addr, uint32_t value, uint8_t params);

// Sort operation
void nmp_sort(void* addr, uint32_t count, bool ascending);

// Reduce operation
uint32_t nmp_reduce_sum(void* addr, uint32_t count);
uint32_t nmp_reduce_max(void* addr, uint32_t count);
uint32_t nmp_reduce_min(void* addr, uint32_t count);

// Filter operation
uint32_t nmp_filter_gt(void* addr, uint32_t count, uint32_t threshold);

// Map operation
void nmp_map_scale(void* addr, uint32_t count, uint32_t factor);
void nmp_map_add(void* addr, uint32_t count, uint32_t value);
```

---

## Example Usage

### Example 1: Search Operation
```c
// Search for value 0x42 in array
uint32_t array[100];
uint32_t result;

// Assembly
__asm__ volatile(
    "li t0, 0x42\n"
    "nmp.search %0, %1, t0, 0x00"
    : "=r"(result)
    : "r"(array)
    : "t0"
);

// Using intrinsic
result = nmp_search(array, 0x42, 0x00);

if (result != 0xFFFFFFFF) {
    printf("Found at index: %d\n", result - (uint32_t)array);
}
```

### Example 2: Sort Operation
```c
// Sort 32 elements in ascending order
uint8_t data[32];

// Assembly
__asm__ volatile(
    "li t0, 32\n"
    "nmp.sort zero, %0, t0, 0x20"
    :
    : "r"(data)
    : "t0"
);

// Using intrinsic
nmp_sort(data, 32, true);
```

### Example 3: Reduce Operation
```c
// Calculate sum of 64 elements
uint32_t values[64];
uint32_t sum;

// Assembly
__asm__ volatile(
    "li t0, 64\n"
    "nmp.reduce %0, %1, t0, 0x00"
    : "=r"(sum)
    : "r"(values)
    : "t0"
);

// Using intrinsic
sum = nmp_reduce_sum(values, 64);
printf("Sum: %d\n", sum);
```

### Example 4: Performance Measurement
```c
// Measure NMP operation performance
uint32_t start_cycles, end_cycles;
uint32_t data[256];

// Read cycle counter before
__asm__ volatile("rdcycle %0" : "=r"(start_cycles));

// Perform NMP operation
nmp_reduce_sum(data, 256);

// Read cycle counter after
__asm__ volatile("rdcycle %0" : "=r"(end_cycles));

printf("Operation took %d cycles\n", end_cycles - start_cycles);
```

---

## Status Codes

### nmp_status_o Field
| Bit | Description |
|-----|-------------|
| 7 | Error flag |
| 6 | Overflow flag |
| 5 | Busy flag |
| 4 | Operation complete |
| 3:0 | Unit-specific status |

### Error Codes (when bit 7 = 1)
| Code | Description |
|------|-------------|
| 0x80 | Invalid operation |
| 0x81 | Memory error |
| 0x82 | Overflow error |
| 0x83 | Timeout error |
| 0x84 | Invalid parameters |
| 0x85 | Unit busy |

---

## Debugging Tips

### Common Integration Issues

1. **NMP operations hang**
   - Check memory arbitration
   - Verify mem_gnt signal is asserted
   - Check clock and reset signals

2. **Incorrect results**
   - Verify funct7 encoding
   - Check data alignment
   - Verify memory endianness

3. **Performance lower than expected**
   - Check memory contention
   - Verify clock frequency
   - Review arbitration policy

### Simulation Checkpoints

1. Run individual unit testbenches:
   ```bash
   vsim -do "run -all" tb_nmp_top
   vsim -do "run -all" tb_nmp_search
   vsim -do "run -all" tb_nmp_sort
   ```

2. Check waveforms for:
   - Proper handshaking (req/gnt/valid)
   - Memory transactions
   - State machine transitions
   - Result validity

3. Verify timing constraints:
   - Setup/hold violations
   - Critical path analysis
   - Memory access patterns

---

## Contact Information

For questions or issues with NMP integration:
- Check implementation report: `NMP_Implementation_Report.md`
- Review hardware specification: `NMP_Hardware_Specification.md`
- Run testbenches in `pulpino/tb/nmp/`

---

**Document Version**: 1.0  
**Date**: September 2024  
**Status**: Ready for Integration
