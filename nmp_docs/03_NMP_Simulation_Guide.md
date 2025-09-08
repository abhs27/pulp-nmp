# NMP Processor Testbench and Simulation Guide

## Overview
This directory contains comprehensive testbenches for the Near-Memory Processing (NMP) units. The main testbench `tb_nmp_top.sv` verifies all major NMP operations including Search, Sort, and Reduce functions.

## Testbench Features

### Test Coverage
The testbench includes the following test scenarios:

1. **Search Operations**
   - Search for existing values
   - Search for non-existent values
   - Performance testing with large arrays

2. **Sort Operations**
   - Ascending sort of unsorted arrays
   - Verification of sorted output
   - In-place sorting validation

3. **Reduce Operations**
   - Sum reduction
   - Min reduction
   - Max reduction
   - Array aggregation functions

4. **Performance Measurements**
   - Cycle counting for each operation
   - Time measurements
   - Large dataset processing

### Memory Model
- Simple memory model with configurable size (default: 1024 words)
- Single-cycle read/write latency
- Address bounds checking
- Error injection capability

## Directory Structure
```
pulpino_workspace/
├── rtl/nmp_units/         # NMP RTL source files
│   ├── include/           # Interface definitions
│   └── src/               # Module implementations
├── tb/nmp_rtl/            # Testbenches
│   └── tb_nmp_top.sv      # Main testbench
└── scripts/               # Simulation scripts
    ├── run_nmp_sim.sh     # Linux/Unix script
    └── run_nmp_sim.bat    # Windows script
```

## Running the Simulation

### Method 1: Using Automated Scripts

#### Linux/Unix/WSL:
```bash
cd scripts
chmod +x run_nmp_sim.sh
./run_nmp_sim.sh
```

#### Windows:
```cmd
cd scripts
run_nmp_sim.bat
```

The scripts will automatically:
- Detect available simulators
- Compile all RTL and testbench files
- Run the simulation
- Report pass/fail status

### Method 2: Manual Simulation with ModelSim/QuestaSim

1. **Create work directory:**
```bash
cd pulpino_workspace
mkdir -p sim/work
cd sim/work
```

2. **Create work library:**
```bash
vlib work
```

3. **Compile interfaces:**
```bash
vlog -sv ../../rtl/nmp_units/include/nmp_if.sv
vlog -sv ../../rtl/nmp_units/include/nmp_mem_if.sv
```

4. **Compile RTL modules:**
```bash
vlog -sv ../../rtl/nmp_units/src/nmp_search_unit.sv
vlog -sv ../../rtl/nmp_units/src/nmp_sort_unit.sv
vlog -sv ../../rtl/nmp_units/src/nmp_reduce_unit.sv
vlog -sv ../../rtl/nmp_units/src/nmp_filter_unit.sv
vlog -sv ../../rtl/nmp_units/src/nmp_map_unit.sv
vlog -sv ../../rtl/nmp_units/src/nmp_controller.sv
vlog -sv ../../rtl/nmp_units/src/nmp_top.sv
```

5. **Compile testbench:**
```bash
vlog -sv ../../tb/nmp_rtl/tb_nmp_top.sv
```

6. **Run simulation:**
```bash
# Command line mode
vsim -c -do "run -all; quit" tb_nmp_top

# GUI mode for waveform viewing
vsim tb_nmp_top
# In the GUI console, type: run -all
```

### Method 3: Using Vivado Simulator (xsim)

1. **Create file list:**
```bash
cat > filelist.f << EOF
rtl/nmp_units/include/nmp_if.sv
rtl/nmp_units/include/nmp_mem_if.sv
rtl/nmp_units/src/nmp_search_unit.sv
rtl/nmp_units/src/nmp_sort_unit.sv
rtl/nmp_units/src/nmp_reduce_unit.sv
rtl/nmp_units/src/nmp_filter_unit.sv
rtl/nmp_units/src/nmp_map_unit.sv
rtl/nmp_units/src/nmp_controller.sv
rtl/nmp_units/src/nmp_top.sv
tb/nmp_rtl/tb_nmp_top.sv
EOF
```

2. **Compile:**
```bash
xvlog -sv -f filelist.f
```

3. **Elaborate:**
```bash
xelab -debug typical -top tb_nmp_top -snapshot tb_nmp_top_snap
```

4. **Simulate:**
```bash
xsim tb_nmp_top_snap -runall
```

### Method 4: Using Synopsys VCS

```bash
vcs -sverilog -debug_all \
    rtl/nmp_units/include/*.sv \
    rtl/nmp_units/src/*.sv \
    tb/nmp_rtl/tb_nmp_top.sv \
    -o simv

./simv
```

## Expected Output

### Successful Simulation
```
==================================================
     NMP TOP MODULE TESTBENCH STARTED
==================================================

[150] Applying reset...
[250] Reset complete
[250] Initializing memory...

========================================
Test 1: SEARCH Operation
========================================
[PASS] Found at correct index: 10
[PASS] Correctly returned NOT FOUND

========================================
Test 2: SORT Operation
========================================
[PASS] Array correctly sorted

========================================
Test 3: REDUCE Operations
========================================
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

## Debugging Tips

1. **Enable Waveform Generation:**
   - The testbench automatically generates `nmp_top.vcd` file
   - Open with GTKWave: `gtkwave nmp_top.vcd`

2. **Verbose Logging:**
   - All memory transactions are logged
   - Operation details printed for each test

3. **Check Log Files:**
   - `simulation.log` contains full simulation output
   - `transcript` (ModelSim) contains command history

## Customizing Tests

### Modify Test Parameters
Edit `tb_nmp_top.sv` to change:
- `CLK_PERIOD`: Clock frequency
- `MEM_SIZE`: Memory size
- `TIMEOUT`: Simulation timeout

### Add New Tests
Add new test tasks following the pattern:
```systemverilog
task test_custom();
    logic [31:0] result;
    test_count++;
    
    execute_nmp_operation(
        operation,  // 3-bit operation code
        base_addr,  // Base address
        operand,    // Second operand
        config,     // Configuration
        result      // Output result
    );
    
    // Check results...
endtask
```

## Troubleshooting

### Common Issues

1. **Compilation Errors:**
   - Ensure all RTL files are implemented
   - Check file paths in scripts
   - Verify SystemVerilog support in simulator

2. **Simulation Hangs:**
   - Check for infinite loops in RTL
   - Verify handshaking signals
   - Increase timeout value

3. **Tests Failing:**
   - Review memory initialization
   - Check operation configurations
   - Verify expected values

## Performance Analysis

The testbench reports:
- Hardware cycle counts per operation
- Simulation time measurements
- Memory access patterns

Use these metrics to optimize:
- Algorithm implementations
- Memory access patterns
- Pipeline efficiency

## Next Steps

After successful simulation:
1. Run synthesis to check timing
2. Perform gate-level simulation
3. Integrate with PULPino core
4. Run system-level tests

## Support

For issues or questions:
- Check simulation.log for detailed error messages
- Review RTL implementation for protocol compliance
- Verify interface signal connections
