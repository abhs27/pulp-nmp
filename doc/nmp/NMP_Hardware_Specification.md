# Near Memory Processing (NMP) Hardware Specification

## Overview
This document provides detailed hardware specifications for the Near Memory Processing (NMP) unit implemented for PULPino.

## Architecture

### Top-Level Block Diagram
```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐
│  PULPino Core   │◄──►│ NMP Controller  │◄──►│    Memory    │
│                 │    │                 │    │  Interface   │
└─────────────────┘    └─────────────────┘    └──────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   NMP Units     │
                    │                 │
                    │ ┌─────────────┐ │
                    │ │Search Unit  │ │
                    │ ├─────────────┤ │
                    │ │Sort Unit    │ │
                    │ ├─────────────┤ │
                    │ │Reduce Unit  │ │
                    │ ├─────────────┤ │
                    │ │Filter Unit  │ │
                    │ ├─────────────┤ │
                    │ │Map Unit     │ │
                    │ └─────────────┘ │
                    └─────────────────┘
```

## Interface Specifications

### Core Interface (nmp_if)
- **Data Width**: 32-bit
- **Address Space**: Full 32-bit addressing
- **Handshaking**: req/gnt/valid protocol
- **Operation Encoding**: 3-bit function code + 7-bit sub-function

### Memory Interface (nmp_mem_if)
- **Data Width**: 32-bit
- **Burst Support**: 1, 4, 8, 16 word bursts
- **Arbitration**: Round-robin between NMP units
- **Error Handling**: Built-in error detection and reporting

### Configuration Interface (nmp_config_if)
- **Control Registers**: Enable/disable, reset, clock gating
- **Status Reporting**: Performance counters, unit status
- **Interrupt Generation**: Operation completion and error events

## NMP Operations

### Search Unit (ID: 0x01)
- **Operations**: Linear search, pattern matching
- **Data Types**: 8, 16, 32-bit elements
- **Features**: Exact match, range search, pattern mask
- **Performance**: ~100M comparisons/second

### Sort Unit (ID: 0x02)
- **Algorithms**: Bubble sort (≤64 elements)
- **Data Types**: 8, 16, 32-bit elements
- **Modes**: Ascending/descending
- **Performance**: ~10K elements/second

### Reduce Unit (ID: 0x03)
- **Operations**: SUM, PRODUCT, MIN, MAX, AND, OR, XOR
- **Data Types**: 8, 16, 32-bit elements
- **Features**: Overflow detection
- **Performance**: ~200M operations/second

### Filter Unit (ID: 0x04)
- **Filter Types**: Range, threshold
- **Data Types**: 8, 16, 32-bit elements
- **Modes**: In-place or copy to new location
- **Performance**: ~150M elements/second

### Map Unit (ID: 0x05)
- **Operations**: Scale, add, square, abs, negate, shift
- **Data Types**: 8, 16, 32-bit elements
- **Modes**: In-place or copy to new location
- **Performance**: ~100M transformations/second

## Instruction Encoding

### NMP Instruction Format
```
31    25 24   20 19   15 14  12 11    7 6     0
+-------+-------+-------+-----+-------+-------+
| funct7| rs2   | rs1   |funct3| rd   |opcode |
+-------+-------+-------+-----+-------+-------+
```

- **opcode**: 0x6b (OPCODE_NMP_OP)
- **funct3**: Operation type (000=SEARCH, 001=SORT, etc.)
- **funct7**: Sub-operation and configuration
- **rs1**: Base address register
- **rs2**: Data/size register
- **rd**: Result register

## Register File Integration

### ALU Operation Codes
- ALU_NMP_SEARCH  = 7'b1100000
- ALU_NMP_SORT    = 7'b1100001
- ALU_NMP_REDUCE  = 7'b1100010
- ALU_NMP_FILTER  = 7'b1100011
- ALU_NMP_MAP     = 7'b1100100

## Memory Requirements

### Resource Utilization
- **Logic Elements**: ~5,000 LEs
- **Memory**: 2KB internal buffers (sort unit)
- **I/O**: Shared with existing PULPino memory interface

### Performance Characteristics
- **Clock Frequency**: 100 MHz (matches PULPino)
- **Memory Bandwidth**: 400 MB/s peak
- **Latency**: 2-10 cycles instruction decode to execution

## Power Management
- **Clock Gating**: Individual unit clock gating
- **Power States**: Active, idle, disabled
- **Estimated Power**: 25% increase over base PULPino

## Error Handling
- **Memory Errors**: Automatic detection and reporting
- **Operation Errors**: Invalid operation codes, overflow
- **Recovery**: Graceful error handling with status reporting

## Verification
- **Unit Tests**: Individual testbenches for each NMP unit
- **Integration Tests**: Full system testing
- **Coverage**: >95% code coverage target
