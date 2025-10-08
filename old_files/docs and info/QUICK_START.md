# NMP Hash System - Quick Start Guide

## Prerequisites
- ModelSim/QuestaSim
- Python 3.6+
- SystemVerilog compiler

## 5-Minute Quick Start

### Step 1: Explore Hash Generation
```bash
cd /home/rohan/major_project/pulpino_workspace/pulpino/rtl/nmp_working
./generate_hash_table.py
```

This will show you:
- Example hash values for different address combinations
- Collision rate analysis
- How to generate SystemVerilog initialization code

### Step 2: Compile the Design
```bash
./compile_nmp_hash.sh
```

Expected output: Green checkmarks for all modules

### Step 3: Run Tests
```bash
cd work
vsim -work work tb_nmp_hash_system -do "run -all; quit"
```

Or for GUI mode:
```bash
vsim -work work tb_nmp_hash_system
# In ModelSim: run -all
```

### Step 4: View Results
Look for:
```
=================================================================
  Test Summary
=================================================================
  Total Tests: 7
  Passed:      7
  Failed:      0
=================================================================
  ALL TESTS PASSED!
```

## File Overview

| File | Purpose |
|------|---------|
| `nmp_top_hash.sv` | Main module - use this in your design |
| `nmp_hash_generator.sv` | Reference for compiler implementation |
| `tb_nmp_hash_system.sv` | Example usage patterns |
| `generate_hash_table.py` | Utility for hash generation |

## Basic Usage Example

### In Your Compiler/Software:
```python
from generate_hash_table import generate_hash, create_nmp_instruction

# Step 1: Generate hash
hash_val = generate_hash(0x10000000, 0x20000000, 0x30000000)

# Step 2: Create instruction
instr = create_nmp_instruction(hash_val, array_size=8, hash_mode=True)

# Step 3: Initialize ALT (one-time setup)
# (Send write commands to ALT before first use)

# Step 4: Execute NMP operation
# (Send instruction to NMP unit)
```

### In Your RTL Testbench:
```verilog
// Initialize ALT
@(posedge clk);
alt_write_enable = 1;
alt_write_hash_index = 17'h1A4B3;
alt_write_rs1_base = 32'h10000000;
alt_write_rs2_base = 32'h20000000;
alt_write_rd_base = 32'h30000000;
@(posedge clk);
alt_write_enable = 0;

// Execute operation
@(posedge clk);
instruction = 32'h3496F86B;  // Hash mode instruction
instruction_valid = 1;
@(posedge clk);
instruction_valid = 0;

// Wait for completion
wait(inter_flag);
```

## Key Instruction Format

```
Hash Mode:  bit[14] = 1, bits[31:15] = hash value
Legacy Mode: bit[14] = 0
```

Example:
```
0x3496F86B = Hash mode, hash=0x1A4B3, size=8, ADD operation
0x00000F6B = Legacy mode, size=8, ADD operation
```

## Common Tasks

### Generate hash for new address set:
```python
python3 -c "from generate_hash_table import generate_hash; print(hex(generate_hash(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC)))"
```

### Check collision rate:
Run `generate_hash_table.py` and select collision test option

### Debug hash mismatch:
1. Print hash in Python: `print(hex(generate_hash(...)))`
2. Check ALT write: Look for hash value in ALT write transaction
3. Verify instruction: Check bits[31:15] of instruction match hash

## Waveform Signals to Monitor

Critical signals for debugging:
- `use_hash_mode` - Should be 1 for hash mode
- `hash_index` - Extracted from instruction[31:15]
- `hash_addr_valid` - Goes high when addresses retrieved
- `hash_error` - Asserts if hash not found
- `current_state` - FSM state (2=HASH_LOOKUP, 3=EXECUTE_INIT)

## Performance Metrics

Watch for these in your simulation:
- **Hash lookup time:** Should be 3 cycles
- **Total operation time:** Hash mode ~7-12 cycles faster than legacy
- **ALT access pattern:** One read per operation in hash mode

## Next Steps

1. Read `NMP_HASH_SYSTEM_README.md` for detailed architecture
2. Modify testbench for your specific use cases
3. Integrate `nmp_top_hash` into your system
4. Implement compiler-side hash generation

## Troubleshooting

**Problem:** Testbench fails with "Hash not found"
- **Fix:** ALT must be initialized before use. See testbench TEST 3.

**Problem:** Wrong results in hash mode
- **Fix:** Verify hash calculation matches between Python and HDL

**Problem:** Compilation errors
- **Fix:** Ensure all dependencies (nmp_alu.sv, etc.) are present

**Problem:** Simulation timeout
- **Fix:** Check AXI interfaces are responding (ready signals)

## Support Files Location

```
rtl_nmp/              <- All RTL modules
tests_nmp/            <- Testbench
docs and info/        <- This file and README
generate_hash_table.py <- Hash generation utility
compile_nmp_hash.sh   <- Compilation script
```

---

**For detailed information, see:** `NMP_HASH_SYSTEM_README.md`
