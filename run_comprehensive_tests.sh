#!/bin/bash

# NMP Hash System - Comprehensive Test Runner
# This script compiles and runs the comprehensive test suite

echo "========================================"
echo "NMP Hash System - Test Runner"
echo "========================================"
echo ""

# Check if ModelSim is available
if ! command -v vlog &> /dev/null; then
    echo "ERROR: ModelSim (vlog) not found in PATH"
    echo "Please make sure ModelSim is installed and in your PATH"
    exit 1
fi

# Set working directory
WORK_DIR="/home/rohan/major_project/pulpino_workspace/pulpino/rtl/nmp_working"
cd "$WORK_DIR"

# Configuration
GENERATE_VCD=1  # Set to 1 to generate VCD waveforms, 0 to disable
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SIM_DIR="simulations/sim_${TIMESTAMP}"
VCD_FILE="${SIM_DIR}/nmp_test_${TIMESTAMP}.vcd"

# Create simulation directory
if [ $GENERATE_VCD -eq 1 ]; then
    echo "Creating simulation directory: ${SIM_DIR}"
    mkdir -p "${SIM_DIR}"
fi

# Create work library if it doesn't exist
if [ ! -d "work" ]; then
    echo "Creating work library..."
    vlib work
fi

echo "Step 1: Compiling RTL files..."
vlog -work work \
    rtl_nmp/nmp_addr_gen.sv \
    rtl_nmp/nmp_address_lookup_table.sv \
    rtl_nmp/nmp_alu.sv \
    rtl_nmp/nmp_axi_master.sv \
    rtl_nmp/nmp_decoder_hash.sv \
    rtl_nmp/nmp_fsm_hash.sv \
    rtl_nmp/nmp_hash_addr_decoder.sv \
    rtl_nmp/nmp_hash_generator.sv \
    rtl_nmp/nmp_top_hash.sv

if [ $? -ne 0 ]; then
    echo "ERROR: RTL compilation failed"
    exit 1
fi

echo ""
echo "Step 2: Compiling testbench..."
vlog -work work tests_nmp/tb_final_working.sv

if [ $? -ne 0 ]; then
    echo "ERROR: Testbench compilation failed"
    exit 1
fi

echo ""
echo "Step 3: Running comprehensive tests..."
echo "========================================"

# Prepare simulation commands based on VCD configuration
if [ $GENERATE_VCD -eq 1 ]; then
    echo "VCD generation enabled: ${VCD_FILE}"
    vsim -c -do "vcd file ${VCD_FILE}; vcd add -r /*; run -all; quit -f" work.tb_final_working
else
    vsim -c -do "run -all; quit -f" work.tb_final_working
fi

# Move transcript to simulation directory if VCD was generated
if [ $GENERATE_VCD -eq 1 ] && [ -f "transcript" ]; then
    cp transcript "${SIM_DIR}/"
fi

echo ""
echo "========================================"
echo "Test execution complete!"
if [ $GENERATE_VCD -eq 1 ]; then
    echo ""
    echo "Simulation files saved in: ${SIM_DIR}"
    if [ -f "${VCD_FILE}" ]; then
        echo "VCD waveform file: ${VCD_FILE}"
        echo "View waveforms with: gtkwave ${VCD_FILE}"
    fi
    
    # Create a 'latest' symlink for easy access
    ln -sfn "sim_${TIMESTAMP}" simulations/latest
    echo "Quick access via: simulations/latest"
fi
echo "========================================"
