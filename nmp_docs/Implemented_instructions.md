Five Main NMP Instructions Implemented:



1. NMP_SEARCH (funct3 = 3'b000)

•  Opcode: 0x6B

•  ALU Operation: ALU_NMP_SEARCH (7'b1100000)

•  Function: Hardware-accelerated linear search in memory arrays

•  Configuration (funct7):

•  Bits [2:0]: Data width (32-bit, 16-bit, or 8-bit)

•  Bit 3: Exact match vs pattern match

•  Bit 4: Search direction (ascending/descending)

•  Registers: 

•  rs1: Base address of array

•  rs2: Value to search for

•  rd: Result index (or -1 if not found)



2. NMP_SORT (funct3 = 3'b001)

•  Opcode: 0x6B

•  ALU Operation: ALU_NMP_SORT (7'b1100001)

•  Function: In-memory hardware sorting

•  Configuration (funct7):

•  Bit 0: Sort order (0=ascending, 1=descending)

•  Bits [2:0]: Data width

•  Registers:

•  rs1: Array base address

•  rs2: Array size

•  rd: Status/result



3. NMP_REDUCE (funct3 = 3'b010)

•  Opcode: 0x6B

•  ALU Operation: ALU_NMP_REDUCE (7'b1100010)

•  Function: Reduction operations on arrays

•  Configuration (funct7):

•  Bits [2:0]: Operation type:

◦  000: SUM

◦  001: MIN

◦  010: MAX

◦  011: AVG (average)

◦  100: AND

◦  101: OR

◦  110: XOR

•  Bits [5:3]: Data width

•  Registers:

•  rs1: Array base address

•  rs2: Array size

•  rd: Reduction result



4. NMP_FILTER (funct3 = 3'b011)

•  Opcode: 0x6B

•  ALU Operation: ALU_NMP_FILTER (7'b1100011)

•  Function: Data filtering operations

•  Configuration (funct7):

•  Range and threshold filtering capabilities

•  In-place or copy-to-destination modes

•  Registers:

•  rs1: Source array address

•  rs2: Filter criteria/size

•  rd: Result count/status



5. NMP_MAP (funct3 = 3'b100)

•  Opcode: 0x6B

•  ALU Operation: ALU_NMP_MAP (7'b1100100)

•  Function: Element-wise transformations on arrays

•  Configuration (funct7):

•  Transformation operation type

•  Data width configuration

•  Registers:

•  rs1: Source array address

•  rs2: Transform parameter/size

•  rd: Result status



Key Implementation Details:



1. Instruction Format: All NMP instructions use RISC-V R-type format:

2. Hardware Units: Each operation has a dedicated hardware unit:

•  nmp_search_unit.sv

•  nmp_sort_unit.sv

•  nmp_reduce_unit.sv

•  nmp_filter_unit.sv

•  nmp_map_unit.sv

3. Controller: nmp_controller.sv dispatches operations to appropriate units using an FSM with states: IDLE → DECODE → DISPATCH → WAIT_RESPONSE → COMPLETE

4. Performance Targets (at 100 MHz):

•  Search: 100M comparisons/second

•  Sort: 50M operations/second

•  Reduce: 200M operations/second

•  Filter: 150M elements/second

•  Map: 100M transformations/second

5. Critical Note: The decoder implementation is currently NOT integrated into riscv_decoder.sv, meaning these instructions will trigger illegal instruction exceptions until the decoder code from NMP_DECODER_IMPLEMENTATION.sv is added to the main decoder.



All five NMP instructions are fully implemented in RTL but require decoder integration to be functional in the processor pipeline.
