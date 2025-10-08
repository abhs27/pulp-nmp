#!/bin/bash

#-----------------------------------------------------------------------------
# Enhanced NMP Unit ModelSim Compilation and Simulation Script
# Project: PULPino NMP Extension
# Date: 2025-09-21
# Features: Comprehensive performance monitoring, IPC, throughput analysis
#           Organized simulation folder structure
#-----------------------------------------------------------------------------

echo "========================================================================"
echo "Enhanced NMP Unit ModelSim Simulation with Performance Analytics"
echo "========================================================================"

# Set ModelSim paths (adjust if needed)
VSIM_PATH="vsim"
VLIB_PATH="vlib"
VLOG_PATH="vlog"

# Configuration options
USE_ENHANCED_TB=1  # Use enhanced testbench with performance metrics
GENERATE_VCD=1     # Generate VCD waveform file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SIM_DIR="simulation/sim_${TIMESTAMP}"
PERFORMANCE_LOG="${SIM_DIR}/nmp_performance.log"

# Function to print colored output
print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Create simulation directory structure
print_status "Creating simulation directory: ${SIM_DIR}"
mkdir -p "${SIM_DIR}"
mkdir -p simulation

# Clean previous work
print_status "Cleaning previous work directory..."
rm -rf work
rm -f *.vcd
rm -f transcript
rm -f vsim.wlf

# Create work library
print_status "Creating work library..."
$VLIB_PATH work

# Check if ModelSim tools are available
if ! command -v $VSIM_PATH &> /dev/null; then
    print_error "ModelSim not found! Please ensure ModelSim is in your PATH."
    exit 1
fi

# Compile SystemVerilog files
print_status "Compiling NMP unit design files..."
$VLOG_PATH -sv -work work rtl_nmp/*.sv

# Check compilation status
if [ $? -ne 0 ]; then
    print_error "RTL compilation failed!"
    exit 1
fi

# Choose testbench based on configuration
if [ $USE_ENHANCED_TB -eq 1 ]; then
    print_status "Compiling enhanced testbench with performance monitoring..."
    $VLOG_PATH -sv -work work tests_nmp/nmp_proof_enhanced.sv
    TB_MODULE="nmp_proof"
    print_status "Using enhanced testbench: nmp_proof_enhanced.sv"
else
    print_status "Compiling standard testbench..."
    $VLOG_PATH -sv -work work tests_nmp/nmp_proof.sv
    TB_MODULE="nmp_proof"
    print_status "Using standard testbench: nmp_proof.sv"
fi

# Check testbench compilation status
if [ $? -ne 0 ]; then
    print_error "Testbench compilation failed!"
    exit 1
fi

print_success "Compilation successful!"
echo ""

# Prepare simulation commands
SIM_COMMANDS="run -all"
VCD_FILE="${SIM_DIR}/nmp_enhanced_${TIMESTAMP}.vcd"
SIM_OUTPUT_LOG="${SIM_DIR}/simulation_output_${TIMESTAMP}.log"

if [ $GENERATE_VCD -eq 1 ]; then
    SIM_COMMANDS="vcd file ${VCD_FILE}; vcd add -r /*; $SIM_COMMANDS"
    print_status "VCD generation enabled: ${VCD_FILE}"
fi

# Run simulation
print_status "Starting enhanced NMP simulation..."
print_status "Simulation includes: IPC, Throughput, Memory Bandwidth, Execution Efficiency"
print_status "All outputs will be saved in: ${SIM_DIR}"
echo ""

# Create comprehensive simulation command
$VSIM_PATH -c -do "
    # Set up simulation environment
    onbreak {resume}
    
    # Configure transcript logging
    transcript file $PERFORMANCE_LOG
    
    # Load design
    # Run with performance monitoring
    $SIM_COMMANDS
    
    # Additional performance queries (if signals are available)
    # These would need to be adapted based to your specific RTL signals
    echo \"=== ADDITIONAL PERFORMANCE METRICS ===\"
    echo \"Clock Frequency: 100MHz (10ns period)\"
    echo \"Simulation Timestamp: $(date)\"
    
    quit -sim
    exit
" work.$TB_MODULE | tee "${SIM_OUTPUT_LOG}"

# Check simulation status
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    print_error "Simulation failed!"
    exit 1
fi

# Move additional files to simulation directory
print_status "Organizing simulation files..."

# Move transcript file if it exists
if [ -f "transcript" ]; then
    mv transcript "${SIM_DIR}/"
fi

# Move any remaining VCD files
if ls *.vcd 1> /dev/null 2>&1; then
    mv *.vcd "${SIM_DIR}/"
fi

# Move any remaining log files
if ls *.log 1> /dev/null 2>&1; then
    mv *.log "${SIM_DIR}/"
fi

# Create a summary file
cat > "${SIM_DIR}/simulation_summary.txt" << EOFSUMMARY
===============================================
NMP Simulation Summary
===============================================
Timestamp: $(date)
Simulation ID: ${TIMESTAMP}
Directory: ${SIM_DIR}

Files Generated:
- simulation_output_${TIMESTAMP}.log (Complete simulation log)
- nmp_performance.log (Performance metrics)
- nmp_enhanced_${TIMESTAMP}.vcd (Waveform file)
- transcript (ModelSim transcript)
- simulation_summary.txt (This file)

Testbench Used: $([ $USE_ENHANCED_TB -eq 1 ] && echo "Enhanced (nmp_proof_enhanced.sv)" || echo "Standard (nmp_proof.sv)")
VCD Generation: $([ $GENERATE_VCD -eq 1 ] && echo "Enabled" || echo "Disabled")

Commands to analyze results:
- View waveforms: gtkwave ${VCD_FILE}
- View performance: cat ${PERFORMANCE_LOG}
- View full log: cat ${SIM_OUTPUT_LOG}
===============================================
EOFSUMMARY

echo ""
print_success "Simulation completed successfully!"
echo ""

# Post-simulation reporting
print_status "=== POST-SIMULATION ANALYSIS ==="

# Check if VCD file was generated
if [ $GENERATE_VCD -eq 1 ] && [ -f "${VCD_FILE}" ]; then
    print_success "VCD waveform file generated: ${VCD_FILE}"
    echo "           You can view it with: gtkwave ${VCD_FILE}"
fi

# Check for performance log
if [ -f "$PERFORMANCE_LOG" ]; then
    print_success "Performance log generated: $PERFORMANCE_LOG"
fi

# Check for simulation output
if [ -f "${SIM_OUTPUT_LOG}" ]; then
    print_success "Complete simulation log: ${SIM_OUTPUT_LOG}"
    
    # Extract key performance metrics if they exist in the log
    print_status "=== QUICK PERFORMANCE SUMMARY ==="
    
    if grep -q "PERFORMANCE REPORT" "${SIM_OUTPUT_LOG}"; then
        echo "Performance metrics found in simulation output:"
        grep -A 20 "PERFORMANCE REPORT" "${SIM_OUTPUT_LOG}" | head -25
    else
        print_warning "Enhanced performance metrics not found. Check if enhanced testbench was used."
    fi
fi

# Performance analysis suggestions
print_status "=== PERFORMANCE ANALYSIS SUGGESTIONS ==="
echo "1. Check IPC (Instructions Per Cycle) - target > 0.5 for efficient execution"
echo "2. Monitor memory bandwidth utilization - should be balanced"
echo "3. Analyze execution efficiency - higher % indicates better resource usage"
echo "4. Review average cycles per operation for optimization opportunities"

# File summary
echo ""
print_status "=== GENERATED FILES IN ${SIM_DIR} ==="
ls -la "${SIM_DIR}/"

# Create a latest symlink for easy access
ln -sfn "sim_${TIMESTAMP}" simulation/latest
print_status "Created symlink: simulation/latest -> sim_${TIMESTAMP}"

# Show directory structure
echo ""
print_status "=== SIMULATION DIRECTORY STRUCTURE ==="
tree simulation/ 2>/dev/null || find simulation/ -type f | sort

echo ""
print_success "Enhanced NMP simulation completed!"
print_status "All simulation files organized in: ${SIM_DIR}"
print_status "Quick access via symlink: simulation/latest"
echo "========================================================================"
