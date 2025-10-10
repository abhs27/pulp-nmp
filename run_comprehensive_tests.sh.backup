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
vsim -c -do "run -all; quit -f" work.tb_final_working

echo ""
echo "========================================"
echo "Test execution complete!"
echo "========================================"
