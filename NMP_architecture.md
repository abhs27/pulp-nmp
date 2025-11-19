# NMP RTL Architecture (V2 - Hash-Only with Multi-Cycle ALU)

## 1. Overview

This document details the enhanced architecture of the Near-Memory Processor (NMP) RTL design. The NMP is a specialized co-processor designed to offload element-wise array operations from a main CPU. It operates directly on data in memory to reduce data movement and offload the main processor.

This version of the NMP has been streamlined to **exclusively use Hash Mode**. The previous "Legacy Mode" has been removed to optimize and simplify the design. In this mode, a custom instruction contains a 17-bit hash that is used as a direct index into a dedicated on-chip memory called the Address Lookup Table (ALT). The ALT provides the base addresses for the two source arrays (rs1, rs2) and the destination array (rd), avoiding the need for initial memory reads to fetch these pointers.

Furthermore, the architecture now incorporates a **multi-cycle Arithmetic Logic Unit (ALU)** capable of handling variable-latency operations, including single-cycle addition/subtraction, 4-cycle multiplication, and 32-cycle division.

## 2. Instruction Format

The NMP uses a custom 32-bit instruction format, identified by the opcode `7'b1101011` (0x6B). The `HM` (Hash Mode) bit from the previous version is now repurposed as the most significant bit of an expanded `funct3`.

```
| 31          :          15 | 14   :   12 | 11   :   7 | 6     :     0 |
|---------------------------|------------|-----------|---------------|
|      hash_index (17)      | funct3 (3) | size (5)  |   opcode (7)  |
```

*   **`opcode` [6:0]:** The custom NMP opcode (0x6B).
*   **`size` [11:7]:** A 5-bit value indicating the number of elements in the arrays to be processed (from 1 to 32).
*   **`funct3` [14:12]:** A 3-bit field that specifies the arithmetic operation:
    *   `3'b000`: ADD
    *   `3'b001`: SUB
    *   `3'b010`: MUL
    *   `3'b011`: DIV
*   **`hash_index` [31:15]:** A 17-bit value used as a direct index into the Address Lookup Table (ALT).

## 3. Top-Level Architecture (`nmp_top_hash`)

The `nmp_top_hash.sv` module integrates all sub-modules and manages the data flow.

### Key Components:

*   **`nmp_decoder_hash` (Instruction Decoder):**
    *   Parses the incoming 32-bit instruction.
    *   Checks for the valid NMP opcode.
    *   Extracts the `array_size`, `funct3`, and `hash_index`.
    *   Generates control signals (e.g., `is_nmp_add`, `is_nmp_mul`) to activate the FSM.

*   **`nmp_fsm_hash` (Finite State Machine):**
    *   The main controller, orchestrating the entire operation sequence.
    *   **New State for Multi-Cycle Ops:** It now includes a wait state to handle the variable latency of the ALU.
    *   **States:**
        *   `IDLE`: Waiting for a valid NMP instruction.
        *   `HASH_LOOKUP`: Directs the `nmp_hash_addr_decoder` to fetch base addresses from the ALT.
        *   `EXECUTE_INIT`: Prepares for the element-wise operation loop.
        *   `EXECUTE_READ`: Reads the current elements from the source arrays.
        *   `EXECUTE_COMPUTE_WAIT`: **(New)** Stalls the FSM, waiting for the `op_done` signal from the ALU. This allows the multiplier or divider to complete its operation.
        *   `EXECUTE_WRITE`: Writes the computed result to the destination array.
        *   `DONE`: The operation is complete; signals an interrupt.
        *   `ERROR`: Entered if a hash is not found or a memory error occurs.

*   **`nmp_alu` (Multi-Cycle Arithmetic Logic Unit):**
    *   A significant enhancement, this unit now manages all arithmetic operations.
    *   It receives a `start_op` signal from the FSM to begin a calculation.
    *   It asserts an `op_done` signal upon completion, which can take 1 cycle (ADD/SUB), 4 cycles (MUL), or over 30 cycles (DIV).
    *   Instantiates the `multiplier` and `divider` modules and routes data accordingly based on `funct3`.

*   **`nmp_address_lookup_table` (ALT):**
    *   A `128K x 96-bit` on-chip memory storing pre-compiled base address triplets (`rs1_base`, `rs2_base`, `rd_base`), indexed by the 17-bit hash.

*   **`nmp_hash_addr_decoder`:**
    *   Interfaces with the ALT to retrieve base addresses based on the instruction's `hash_index`.

*   **`nmp_addr_gen` (Address Generation Unit):**
    *   Calculates the memory address for each array element (`address = base + counter * 4`).

*   **`nmp_axi_master`:**
    *   Handles all AXI4-Lite memory communication for reading source operands and writing destination results.

## 4. Execution Flow

1.  **Instruction Fetch & Decode:** The main processor sends an NMP instruction to `nmp_top_hash`. The `nmp_decoder_hash` validates the opcode and parses the `hash_index`, `funct3`, and `array_size`.

2.  **FSM Activation:** The decoder asserts `nmp_valid_start`, waking the `nmp_fsm_hash` from its `IDLE` state.

3.  **Address Resolution (Hash Mode Only):** The FSM enters `HASH_LOOKUP`. The `hash_index` is passed to the `nmp_hash_addr_decoder` to retrieve the three base addresses from the ALT.

4.  **Execution Loop (for each element from 0 to `array_size - 1`):**
    a.  The FSM enters `EXECUTE_INIT` to reset loop signals.
    b.  It transitions to `EXECUTE_READ`. `nmp_addr_gen` calculates source addresses, and `nmp_axi_master` reads the two operands.
    c.  Once reads are done, the FSM asserts `start_op` and transitions to `EXECUTE_COMPUTE_WAIT`.
    d.  The `nmp_alu` begins its calculation. The FSM stalls in `EXECUTE_COMPUTE_WAIT` until the ALU asserts `op_done`.
    e.  Once `op_done` is high, the FSM transitions to `EXECUTE_WRITE`.
    f.  `nmp_addr_gen` calculates the destination address, and `nmp_axi_master` writes the result from the ALU.
    g.  When the write is complete, the `element_counter` is incremented, and the FSM loops back to `EXECUTE_INIT` for the next element.

5.  **Completion:** After the last element is processed, the FSM transitions to the `DONE` state, raises the `inter_flag`, and returns to `IDLE`.
