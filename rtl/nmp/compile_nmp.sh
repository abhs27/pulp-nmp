#!/bin/bash

#-----------------------------------------------------------------------------
# NMP Unit ModelSim Compilation and Simulation Script
# Project: PULPino NMP Extension
# Date: 2025-09-17
#-----------------------------------------------------------------------------

echo "================================================"
echo "NMP Unit ModelSim Simulation"
echo "================================================"

# Set ModelSim paths (adjust if needed)
VSIM_PATH="vsim"
VLIB_PATH="vlib"
VLOG_PATH="vlog"

# Clean previous work
echo "Cleaning previous work directory..."
rm -rf work
rm -f *.vcd
rm -f transcript
rm -f vsim.wlf

# Create work library
echo "Creating work library..."
$VLIB_PATH work

# Compile SystemVerilog files
echo "Compiling NMP unit design..."
$VLOG_PATH -sv -work work nmp_unit_top.sv

echo "Compiling testbench..."
$VLOG_PATH -sv -work work nmp_unit_tb.sv

# Check compilation status
if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

echo ""
echo "Compilation successful!"
echo ""

# Run simulation
echo "Starting simulation..."
$VSIM_PATH -c -do "
    run -all
    quit -sim
    exit
" work.nmp_unit_tb

echo ""
echo "================================================"
echo "Simulation completed!"
echo "================================================"

# Check if VCD file was generated
if [ -f "nmp_unit_tb.vcd" ]; then
    echo "VCD waveform file generated: nmp_unit_tb.vcd"
    echo "You can view it with GTKWave or similar viewer"
fi
