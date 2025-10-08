#!/bin/bash
#------------------------------------------------------------------------------
# NMP Hash System Compilation Script
# Compiles all hash-based NMP modules and testbench
#------------------------------------------------------------------------------

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "  NMP Hash-Based Address Lookup System - Compilation"
echo "======================================================================"

# Directories
RTL_DIR="./rtl_nmp"
TEST_DIR="./tests_nmp"
WORK_DIR="./work"

# Create work directory
if [ ! -d "$WORK_DIR" ]; then
    mkdir -p "$WORK_DIR"
    echo -e "${GREEN}Created work directory${NC}"
fi

# Clean previous compilation
echo -e "\n${YELLOW}Cleaning previous compilation...${NC}"
rm -rf $WORK_DIR/*
vlib $WORK_DIR/work 2>/dev/null || true

echo -e "\n${YELLOW}Compiling RTL modules...${NC}"

# Compile in dependency order
modules=(
    "$RTL_DIR/nmp_alu.sv"
    "$RTL_DIR/nmp_addr_gen.sv"
    "$RTL_DIR/nmp_axi_master.sv"
    "$RTL_DIR/nmp_hash_generator.sv"
    "$RTL_DIR/nmp_address_lookup_table.sv"
    "$RTL_DIR/nmp_decoder_hash.sv"
    "$RTL_DIR/nmp_hash_addr_decoder.sv"
    "$RTL_DIR/nmp_fsm_hash.sv"
    "$RTL_DIR/nmp_top_hash.sv"
)

for module in "${modules[@]}"; do
    if [ -f "$module" ]; then
        echo -e "  ${GREEN}✓${NC} Compiling $(basename $module)"
        vlog -work $WORK_DIR/work +acc "$module"
    else
        echo -e "  ${RED}✗${NC} Missing: $module"
        exit 1
    fi
done

echo -e "\n${YELLOW}Compiling testbench...${NC}"
if [ -f "$TEST_DIR/tb_nmp_hash_system.sv" ]; then
    echo -e "  ${GREEN}✓${NC} Compiling tb_nmp_hash_system.sv"
    vlog -work $WORK_DIR/work +acc "$TEST_DIR/tb_nmp_hash_system.sv"
else
    echo -e "  ${RED}✗${NC} Missing: $TEST_DIR/tb_nmp_hash_system.sv"
    exit 1
fi

echo -e "\n${GREEN}======================================================================"
echo "  Compilation Complete!"
echo "======================================================================${NC}"
echo ""
echo "To run simulation:"
echo "  vsim -work $WORK_DIR/work tb_nmp_hash_system -do \"run -all\""
echo ""
echo "Or use the run script:"
echo "  ./run_nmp_hash_test.sh"
echo ""

