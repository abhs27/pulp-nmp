# Quick Start Guide - NMP RTL Simulation

## 🚀 Quick Start (3 Simple Steps)

### Option 1: Using Make (Easiest)
```bash
# In WSL terminal, from project root:
make clean    # Clean previous builds
make sim      # Run simulation
make check    # Check results
```

### Option 2: Using Shell Script
```bash
# In WSL terminal:
cd scripts
chmod +x run_nmp_sim.sh
./run_nmp_sim.sh
```

### Option 3: Manual Commands
```bash
# Create work directory
mkdir -p sim/work
cd sim/work

# Compile and run (for ModelSim)
vlib work
vlog -sv ../../rtl/nmp_units/include/*.sv
vlog -sv ../../rtl/nmp_units/src/*.sv
vlog -sv ../../tb/nmp_rtl/tb_nmp_top.sv
vsim -c -do "run -all; quit" tb_nmp_top
```

## ✅ Files Created

### RTL Implementation (Complete)
```
rtl/nmp_units/
├── include/
│   ├── nmp_if.sv          ✓ Core-NMP interface
│   └── nmp_mem_if.sv       ✓ Memory interface
└── src/
    ├── nmp_search_unit.sv  ✓ Search operations
    ├── nmp_sort_unit.sv    ✓ Sort operations
    ├── nmp_reduce_unit.sv  ✓ Reduce operations
    ├── nmp_filter_unit.sv  ✓ Filter operations
    ├── nmp_map_unit.sv     ✓ Map operations
    ├── nmp_controller.sv   ✓ Main controller
    └── nmp_top.sv          ✓ Top module
```

### Testbench (Complete)
```
tb/nmp_rtl/
├── tb_nmp_top.sv           ✓ Comprehensive testbench
└── README_SIMULATION.md    ✓ Detailed guide
```

### Build Tools (Complete)
```
./
├── Makefile                ✓ Build automation
└── scripts/
    └── run_nmp_sim.sh      ✓ Simulation script
```

## 🧪 What the Testbench Tests

1. **Search Operations**
   - Find existing values in memory
   - Handle non-existent values
   - Performance with large arrays

2. **Sort Operations**
   - Sort unsorted arrays in ascending order
   - In-place sorting verification

3. **Reduce Operations**
   - Sum reduction
   - Min/Max finding
   - Array aggregation

4. **Performance Metrics**
   - Cycle counting
   - Timing analysis
   - Memory access patterns

## 📊 Expected Output

```
==================================================
     NMP TOP MODULE TESTBENCH STARTED
==================================================

Test 1: SEARCH Operation
[PASS] Found at correct index: 10
[PASS] Correctly returned NOT FOUND

Test 2: SORT Operation
[PASS] Array correctly sorted

Test 3: REDUCE Operations
[PASS] Sum correct: 55
[PASS] Min correct: 1
[PASS] Max correct: 10

==================================================
              TEST SUMMARY
==================================================
Total Tests:  4
Passed:       7
Failed:       0
Success Rate: 100.0%

RESULT: ALL TESTS PASSED! ✓
==================================================
```

## 🔧 Troubleshooting

### If simulation doesn't run:
1. **Check simulator installation:**
   ```bash
   which vsim   # For ModelSim
   which xsim   # For Vivado
   which vcs    # For Synopsys
   ```

2. **Check file permissions:**
   ```bash
   ls -la rtl/nmp_units/src/
   ls -la tb/nmp_rtl/
   ```

3. **Clean and retry:**
   ```bash
   make clean
   make sim
   ```

### Common Issues:
- **"No simulator found"**: Install ModelSim/QuestaSim or Vivado
- **"File not found"**: Check you're in the correct directory
- **"Permission denied"**: Run `chmod +x scripts/*.sh`

## 📈 Next Steps

After successful simulation:

1. **Integration with PULPino:**
   - Modify `riscv_core.sv` to add NMP interface
   - Connect NMP to memory subsystem
   - Update decode logic for custom instructions

2. **Synthesis:**
   ```bash
   # Run synthesis to check timing
   vivado -mode batch -source synth_nmp.tcl
   ```

3. **Performance Comparison:**
   - Run benchmarks with standard RISC-V
   - Run same benchmarks with NMP
   - Compare cycle counts and power

## 🎯 Project Status

✅ **Completed:**
- All NMP unit RTL implementations
- Comprehensive testbench
- Build automation
- Documentation

🔄 **Next Phase:**
- PULPino integration
- System-level testing
- Performance benchmarking

## 💡 Tips for Success

1. **Always clean before building:**
   ```bash
   make clean && make sim
   ```

2. **Check logs for details:**
   ```bash
   cat sim/work/simulation.log
   ```

3. **View waveforms (if GUI available):**
   ```bash
   make gui  # Opens ModelSim GUI
   ```

4. **Quick iteration:**
   ```bash
   # Edit RTL files, then:
   make sim && make check
   ```

---

**Ready to simulate!** Just run `make sim` from the project root.
