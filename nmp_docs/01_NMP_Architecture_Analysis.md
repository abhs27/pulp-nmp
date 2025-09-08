# PULPino Architecture Analysis for Near Memory Processing Integration

## Executive Summary

This report provides a comprehensive analysis of the PULPino microcontroller architecture and outlines a detailed strategy for integrating Near Memory Processing (NMP) capabilities. PULPino is a single-core RISC-V based system with excellent extensibility features that make it an ideal platform for NMP integration.

## 1. PULPino Architecture Overview

### 1.1 System Hierarchy
```
pulpino_top.sv (Top Level)
├── core_region.sv (Core and Memory Subsystem)
│   ├── riscv_core.sv (RI5CY Core) OR zeroriscy_core.sv (Zero-RISCY)
│   ├── Data Memory (32KB SRAM)
│   ├── Instruction Memory (32KB SRAM)
│   ├── Memory Multiplexer (ram_mux.sv)
│   └── Advanced Debug Unit
├── Peripherals (GPIO, UART, SPI, I2C, etc.)
├── AXI Interconnect
└── Clock and Reset Management
```

### 1.2 Core Variants
- **RI5CY Core**: 4-stage pipeline, supports custom RISC-V extensions
- **Zero-RISCY Core**: 2-stage pipeline, minimal power consumption
- **Recommendation**: Use RI5CY for NMP due to its extensibility

### 1.3 Memory Architecture
- **Data Memory**: 32KB single-port SRAM via `sp_ram_wrap.sv`
- **Instruction Memory**: 32KB single-port SRAM
- **Memory Interface**: AXI4 protocol with custom core interface
- **Arbitration**: `ram_mux.sv` handles core and AXI access conflicts

## 2. Current Extension Points Analysis

### 2.1 Instruction Extension Capability
**Strength**: PULPino already supports extensive custom RISC-V instructions:
- Hardware loops (OPCODE_HWLOOP = 7'h7b)
- SIMD operations (OPCODE_VECOP = 7'h57) 
- Post-increment load/store (OPCODE_LOAD_POST = 7'h0b, OPCODE_STORE_POST = 7'h2b)
- Custom ALU operations (OPCODE_PULP_OP = 7'h5b)

**Available Opcodes for NMP**: 
- 7'h6b, 7'h77 are unused custom opcodes
- Recommend using 7'h6b as OPCODE_NMP_OP

### 2.2 Memory Interface Extension Points
**Key Files for Memory Extension**:
- `core_region.sv`: Memory subsystem integration
- `ram_mux.sv`: Multi-port memory arbitration
- `sp_ram_wrap.sv`: SRAM wrapper interface

**Current Memory Flow**:
```
RISC-V Core → Load-Store Unit → ram_mux → sp_ram (Data Memory)
             ↗                        ↗
Debug/AXI Interface              AXI Memory Interface
```

## 3. Near Memory Processing Integration Strategy

### 3.1 NMP Integration Architecture
```
RISC-V Core
    ↓ (NMP Instructions)
NMP Controller
    ↓ (Memory Requests)
Enhanced ram_mux (3-port)
    ↓
Data Memory ← → NMP Processing Units
    ↓
[Search Unit] [Sort Unit] [Reduction Unit] [Pattern Match Unit]
```

### 3.2 NMP Unit Categories
1. **Search Operations**: Pattern matching, key search
2. **Sorting Operations**: Bubble sort, quick sort, merge sort
3. **Reduction Operations**: Sum, min/max, average
4. **Data Movement**: Copy, transpose, scatter-gather

### 3.3 Instruction Format Design
**Proposed NMP Instruction Format (R-type)**:
```
31    25 24   20 19   15 14  12 11    7 6     0
+-------+-------+-------+-----+-------+-------+
| funct7| rs2   | rs1   |funct3| rd   |opcode |
+-------+-------+-------+-----+-------+-------+
  NMP    Param2  Base    Unit   Result  7'h6b
  Op     /Size   Addr    Type   Reg     (NMP)
```

**Field Definitions**:
- `opcode[6:0] = 7'h6b` (OPCODE_NMP_OP)
- `funct3[2:0]`: NMP unit selection (8 possible units)
- `funct7[6:0]`: NMP operation within unit
- `rs1[4:0]`: Base memory address register
- `rs2[4:0]`: Parameter register (search key, array size, etc.)
- `rd[4:0]`: Result destination register

### 3.4 Memory Integration Strategy
**Enhanced ram_mux Design**:
- **Port 0**: Core data access (highest priority)
- **Port 1**: AXI debug/external access
- **Port 2**: NMP units access (new)

**NMP Memory Interface Protocol**:
- Request/Grant handshaking
- Burst transfer support
- Configurable priority levels
- Memory protection boundaries

## 4. Implementation Approach

### 4.1 Hardware Architecture Changes

#### 4.1.1 Core Integration
**File**: `rtl/core_region.sv`
- Add NMP controller instantiation
- Add NMP memory interface signals
- Integrate NMP ready/valid signals

#### 4.1.2 Memory Subsystem Enhancement
**File**: `rtl/ram_mux.sv`
- Extend to 3-port arbitration
- Add NMP-specific priority handling
- Implement burst transfer support

#### 4.1.3 Instruction Pipeline Integration
**Files**: 
- `ips/riscv/riscv_decoder.sv`: Add NMP instruction decoding
- `ips/riscv/riscv_ex_stage.sv`: Add NMP execution stage
- `ips/riscv/riscv_alu.sv`: Handle NMP operation dispatch

### 4.2 NMP Units Architecture

#### 4.2.1 NMP Controller (`rtl/nmp_controller.sv`)
**Responsibilities**:
- Instruction decoding and dispatch
- Memory request arbitration
- Unit status management
- Exception handling

**Interface**:
```systemverilog
module nmp_controller (
    // Core interface
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] instr_i,
    input  logic        nmp_req_i,
    output logic        nmp_ready_o,
    output logic [31:0] nmp_result_o,
    
    // Memory interface  
    output logic        mem_req_o,
    output logic [31:0] mem_addr_o,
    output logic        mem_we_o,
    output logic [3:0]  mem_be_o,
    output logic [31:0] mem_wdata_o,
    input  logic [31:0] mem_rdata_i,
    input  logic        mem_valid_i,
    
    // NMP units interface
    output logic [7:0]  unit_req_o,
    input  logic [7:0]  unit_ready_i,
    input  logic [31:0] unit_result_i [7:0]
);
```

#### 4.2.2 Processing Units
**Search Unit** (`rtl/nmp_units/nmp_search_unit.sv`):
- Linear search with configurable data width
- Pattern matching with wildcards
- Multi-key search capability

**Sort Unit** (`rtl/nmp_units/nmp_sort_unit.sv`):
- Hardware bubble sort for small arrays
- Merge sort for larger datasets
- Configurable comparison functions

**Reduction Unit** (`rtl/nmp_units/nmp_reduction_unit.sv`):
- Parallel tree reduction
- Support for sum, min, max, XOR operations
- Configurable data width (8, 16, 32 bits)

### 4.3 Software Integration

#### 4.3.1 Compiler Intrinsics
**File**: `sw/libs/sys_lib/inc/nmp_intrinsics.h`
```c
// NMP Search Operations
static inline int nmp_search(int *base_addr, int key, int size);
static inline int nmp_pattern_match(char *text, char *pattern, int text_len);

// NMP Sort Operations  
static inline void nmp_bubble_sort(int *array, int size);
static inline void nmp_merge_sort(int *array, int size);

// NMP Reduction Operations
static inline int nmp_sum(int *array, int size);
static inline int nmp_min_max(int *array, int size, int *min, int *max);
```

#### 4.3.2 Runtime Library
**File**: `sw/libs/sys_lib/src/nmp_lib.c`
- Error handling and validation
- Memory alignment utilities
- Performance measurement functions

## 5. Memory Bandwidth and Performance Analysis

### 5.1 Current Memory Performance
- **Data Memory**: 32KB single-port SRAM
- **Access Pattern**: Single 32-bit word per cycle
- **Arbitration**: Fixed priority (Core > AXI > Future NMP)

### 5.2 NMP Performance Projections
**Search Operations**:
- Linear search: O(n) → can be pipelined for 1 access/cycle
- Performance gain: ~10x over software for large arrays

**Sort Operations**:
- Bubble sort: O(n²) → hardware can parallelize comparisons
- Performance gain: ~50x for small arrays (n < 1024)

**Reduction Operations**:
- Tree reduction: O(log n) cycles vs O(n) software
- Performance gain: ~n/log(n) times faster

### 5.3 Memory Bandwidth Requirements
**Total Bandwidth**: 32-bit data @ 25MHz = 100 MB/s
**Allocation**:
- Core operations: 60%
- NMP operations: 35% 
- Debug/External: 5%

## 6. Integration Challenges and Solutions

### 6.1 Memory Arbitration
**Challenge**: Three-way memory arbitration complexity
**Solution**: Weighted round-robin with priority boost for core operations

### 6.2 Pipeline Stalls
**Challenge**: NMP operations may require multiple cycles
**Solution**: Non-blocking NMP execution with result buffering

### 6.3 Memory Coherency
**Challenge**: Core and NMP units accessing same memory
**Solution**: Memory region protection and cache coherency protocols

### 6.4 Power Management
**Challenge**: Additional power consumption from NMP units
**Solution**: Clock gating and power domains for unused units

## 7. Testing and Validation Strategy

### 7.1 Unit Testing
- Individual NMP unit testbenches
- Memory interface protocol verification
- Corner case and stress testing

### 7.2 Integration Testing
- Full system simulation with NMP instructions
- Memory arbitration verification
- Performance benchmarking against software implementations

### 7.3 Application Testing
- Real-world algorithms (sorting, searching, signal processing)
- Multi-threaded access patterns
- Error condition handling

## 8. Implementation Timeline Estimate

### Phase 1 (Weeks 1-4): Infrastructure
- NMP controller design and verification
- Memory arbitration enhancement
- Basic instruction integration

### Phase 2 (Weeks 5-8): Processing Units
- Search unit implementation
- Sort unit implementation  
- Reduction unit implementation

### Phase 3 (Weeks 9-12): Software Integration
- Compiler intrinsics development
- Runtime library implementation
- Test application development

### Phase 4 (Weeks 13-16): Validation
- Comprehensive testing
- Performance optimization
- Documentation and examples

## 9. Expected Benefits

### 9.1 Performance Improvements
- **Search**: 10-20x faster than software
- **Sort**: 20-50x faster for small to medium arrays
- **Reduction**: n/log(n)x improvement

### 9.2 Energy Efficiency
- Reduced CPU cycles for data-intensive operations
- Lower memory traffic due to in-memory processing
- Power gating of unused units

### 9.3 Application Areas
- IoT sensor data processing
- Signal processing applications
- Database query acceleration
- Machine learning inference

## 10. Conclusions and Recommendations

### 10.1 Feasibility Assessment
**Highly Feasible**: PULPino's architecture is well-suited for NMP integration:
- Existing custom instruction support provides foundation
- Memory architecture allows clean integration
- Modular design enables incremental implementation

### 10.2 Key Success Factors
1. **Careful memory arbitration design**
2. **Efficient NMP unit implementations**
3. **Comprehensive software toolchain support**
4. **Thorough testing and validation**

### 10.3 Risk Mitigation
- Start with simple NMP operations (search, sum)
- Incremental integration and testing
- Fallback to software implementations for complex operations
- Early performance measurement and optimization

This analysis demonstrates that PULPino provides an excellent foundation for NMP integration, with clear extension points and a well-structured architecture that can accommodate the proposed enhancements.
