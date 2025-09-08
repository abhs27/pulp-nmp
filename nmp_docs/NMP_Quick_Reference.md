# NMP Quick Reference Card

## 🚀 Essential Commands

### Compile & Run Simulation (WSL/Linux)
```bash
# Quick compile and run
cd pulpino_workspace
make sim

# Or using script
cd scripts
./run_nmp_sim.sh
```

### Manual Compilation (ModelSim)
```bash
cd pulpino_workspace/sim/work
vlib work
vlog -sv ../../rtl/nmp_units/include/*.sv
vlog -sv ../../rtl/nmp_units/src/*.sv
vlog -sv ../../tb/nmp_rtl/tb_nmp_top.sv
vsim -c -do "run -all; quit" tb_nmp_top
```

## 📁 Key File Locations

| Component | Path |
|-----------|------|
| RTL Sources | `pulpino_workspace/rtl/nmp_units/src/` |
| Interfaces | `pulpino_workspace/rtl/nmp_units/include/` |
| Testbench | `pulpino_workspace/tb/nmp_rtl/tb_nmp_top.sv` |
| Scripts | `pulpino_workspace/scripts/` |
| Makefile | `pulpino_workspace/Makefile` |

## 🔧 NMP Operations

### Operation Codes
```systemverilog
3'b000  // SEARCH
3'b001  // SORT
3'b010  // REDUCE
3'b011  // FILTER
3'b100  // MAP
```

### Configuration Bits
```systemverilog
config[1:0]   // Data width (00=32bit, 01=16bit, 10=8bit)
config[2]     // Sort order (0=ascending, 1=descending)
config[5:3]   // Reduce op (000=SUM, 001=MIN, 010=MAX, 011=AVG)
config[6]     // Enable burst mode
```

## 🎯 Module List

1. **nmp_top.sv** - Top-level module
2. **nmp_controller.sv** - Main controller FSM
3. **nmp_search_unit.sv** - Search operations
4. **nmp_sort_unit.sv** - Sort operations
5. **nmp_reduce_unit.sv** - Reduction operations
6. **nmp_filter_unit.sv** - Filter operations
7. **nmp_map_unit.sv** - Map operations
8. **nmp_if.sv** - Core interface
9. **nmp_mem_if.sv** - Memory interface

## 🐛 Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| Iteration limit error | Fixed in controller with registered outputs |
| No simulator found | Install ModelSim or use WSL |
| Permission denied | Run `chmod +x scripts/*.sh` |
| File not found | Check you're in correct directory |

## ✅ Verification Checklist

- [ ] All RTL files compile without errors
- [ ] Testbench runs without iteration limits
- [ ] Search operation returns correct index
- [ ] Sort operation produces sorted array
- [ ] Reduce operations calculate correct values
- [ ] No combinatorial loops in design

## 📊 Expected Test Results

```
Test 1: SEARCH for 0x12345678 → Result: 10 ✓
Test 2: SEARCH for 0xDEADBEEF → Result: 20 ✓
Test 3: SEARCH for non-existent → Result: -1 ✓
Test 4: SORT [45,23,89,12...] → [11,12,23,34...] ✓
Test 5: REDUCE SUM [1..10] → Result: 55 ✓
Test 6: REDUCE MIN [1..10] → Result: 1 ✓
Test 7: REDUCE MAX [1..10] → Result: 10 ✓
```

## 🔄 State Machine States

### Controller States
```
IDLE → DECODE → DISPATCH → WAIT_UNIT → COLLECT → COMPLETE
                    ↓
                  ERROR
```

### Search Unit States
```
IDLE → SETUP → MEM_REQ → MEM_WAIT → COMPARE → FOUND/NOT_FOUND → DONE
```

## 💻 Useful Make Targets

```bash
make         # Run simulation (default)
make sim     # Run simulation
make gui     # GUI mode (ModelSim)
make clean   # Clean build files
make check   # Check test results
make help    # Show help
```

## 📝 Notes

- Controller uses registered outputs to avoid combinatorial loops
- Memory operations have 1-2 cycle latency
- All operations support 8, 16, and 32-bit data widths
- Array size limited by config register (default: 256 elements)
