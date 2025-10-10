# NMP Enhanced Performance Monitoring

This enhanced version of your NMP simulation includes comprehensive performance monitoring capabilities, providing detailed metrics beyond just total cycles.

## Files Created

### 1. Enhanced Testbench
- **`tests_nmp/nmp_proof_enhanced.sv`** - Enhanced testbench with comprehensive performance monitoring

### 2. Enhanced Compilation Script
- **`compile_nmp_enhanced.sh`** - Main enhanced simulation script with performance analytics

### 3. Performance Analysis Tool
- **`performance_analyzer.sh`** - Standalone tool to analyze simulation logs

### 4. Backups
- **`compile_nmp.sh.backup`** - Backup of your original compile script
- **`tests_nmp/nmp_proof.sv.backup`** - Backup of your original testbench

## Performance Metrics Monitored

### Timing Metrics
- **Total Simulation Cycles**: Complete simulation duration in clock cycles
- **Active NMP Cycles**: Cycles when NMP unit is actively processing
- **Idle Cycles**: Cycles when NMP is idle but simulation is running
- **Execution Time**: Real execution time in nanoseconds

### Throughput Metrics
- **Instructions Per Cycle (IPC)**: Efficiency of instruction execution
- **Operations Per Cycle**: Number of operations completed per clock cycle
- **Average Cycles Per Operation**: Average cycles needed for each operation
- **Execution Efficiency**: Percentage of active cycles vs total cycles

### Memory Metrics
- **Total Memory Reads**: Count of AXI read transactions
- **Total Memory Writes**: Count of AXI write transactions  
- **Total AXI Transactions**: Combined read/write transactions
- **Memory Bandwidth Utilization**: Percentage of cycles with memory activity

### Operation Metrics
- **Total Instructions**: Number of instructions processed
- **ALU Operations**: Number of arithmetic/logic operations
- **State Transitions**: FSM state changes
- **Data Elements Processed**: Number of array elements processed

## Usage

### Option 1: Enhanced Simulation (Recommended)
```bash
# Run enhanced simulation with comprehensive performance monitoring
./compile_nmp_enhanced.sh
```

### Option 2: Original Simulation (Basic)
```bash
# Run original simulation (still works, but with limited metrics)
./compile_nmp.sh
```

### Option 3: Analyze Existing Logs
```bash
# Analyze performance from existing simulation logs
./performance_analyzer.sh [optional_logfile]
```

## Output Files

After running the enhanced simulation, you'll get:
- **`nmp_enhanced_YYYYMMDD_HHMMSS.vcd`** - VCD waveform file
- **`simulation_output_YYYYMMDD_HHMMSS.log`** - Complete simulation log
- **`nmp_performance.log`** - ModelSim transcript log
- **`nmp_performance_analysis.txt`** - Performance analysis report (when using analyzer)

## Sample Performance Report

```
╔════════════════════════════════════════════════════════════════╗
║                    NMP PERFORMANCE REPORT                     ║
╠════════════════════════════════════════════════════════════════╣
║ TIMING METRICS:                                               ║
║   Total Simulation Cycles    :        156                     ║
║   Active NMP Cycles          :         89                     ║
║   Idle Cycles                :         67                     ║
║   Execution Time             :    1560.00 ns                  ║
╠════════════════════════════════════════════════════════════════╣
║ THROUGHPUT METRICS:                                           ║
║   Instructions Per Cycle (IPC)     :   0.0064                ║
║   Operations Per Cycle              :   0.0513                ║
║   Average Cycles Per Operation      :    11.13                ║
║   Execution Efficiency              :    57.05%               ║
╠════════════════════════════════════════════════════════════════╣
║ MEMORY METRICS:                                               ║
║   Total Memory Reads         :         16                     ║
║   Total Memory Writes        :          8                     ║
║   Total AXI Transactions     :         24                     ║
║   Memory Bandwidth Util.     :    15.38%                     ║
╠════════════════════════════════════════════════════════════════╣
║ OPERATION METRICS:                                            ║
║   Total Instructions         :          1                     ║
║   ALU Operations             :          8                     ║
║   State Transitions          :          6                     ║
║   Data Elements Processed    :          8                     ║
╚════════════════════════════════════════════════════════════════╝
```

## Performance Analysis Guidelines

### IPC (Instructions Per Cycle)
- **Good**: > 0.5
- **Needs Improvement**: < 0.5
- **Optimization**: Consider pipeline improvements, reduce instruction dependencies

### Execution Efficiency
- **Good**: > 70%
- **Needs Optimization**: < 70%
- **Optimization**: Reduce idle cycles, optimize state machine transitions

### Memory Bandwidth Utilization
- **Balanced**: 10-30% (depends on workload)
- **Too High**: > 80% (potential bottleneck)
- **Too Low**: < 5% (underutilized)

## Configuration Options

Edit `compile_nmp_enhanced.sh` to customize:
```bash
USE_ENHANCED_TB=1    # 1=enhanced testbench, 0=original
GENERATE_VCD=1       # 1=generate VCD file, 0=no VCD
```

## Troubleshooting

### If ALU operation counting fails:
Check if your NMP ALU module has `a_valid` and `b_valid` signals. Update the testbench accordingly.

### If state transition counting fails:
Verify that `dut.u_fsm.current_state` signal path is correct for your FSM implementation.

### If compilation fails:
- Ensure all RTL files in `rtl_nmp/` compile successfully
- Check that signal names in enhanced testbench match your RTL
- Verify ModelSim is properly installed and in PATH

## Next Steps

1. **Run the enhanced simulation**: `./compile_nmp_enhanced.sh`
2. **Analyze the performance report** to identify bottlenecks
3. **Use GTKWave** to visualize waveforms: `gtkwave nmp_enhanced_*.vcd`
4. **Optimize your NMP design** based on the metrics
5. **Compare before/after performance** using the analyzer tool

The enhanced monitoring will help you identify performance bottlenecks and optimization opportunities in your NMP implementation.
