#!/bin/bash
#-----------------------------------------------------------------------------
# Compilation Script for Compressed NMP ALT
# Compiles the compressed address lookup table module and testbench
#-----------------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}NMP Compressed ALT Compilation Script${NC}"
echo -e "${BLUE}============================================================${NC}"

# Create work directory if it doesn't exist
if [ ! -d "work" ]; then
    echo -e "${YELLOW}Creating work directory...${NC}"
    vlib work
fi

# Compile order
echo -e "\n${GREEN}Step 1: Compiling Compressed ALT Module${NC}"
vlog -work work rtl_nmp/nmp_address_lookup_table_compressed.sv
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to compile compressed ALT module${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Compressed ALT module compiled successfully${NC}"

echo -e "\n${GREEN}Step 2: Compiling Testbench${NC}"
vlog -work work tests_nmp/tb_nmp_alt_compressed.sv
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to compile testbench${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Testbench compiled successfully${NC}"

echo -e "\n${BLUE}============================================================${NC}"
echo -e "${GREEN}✓ Compilation Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "\n${YELLOW}To run the simulation:${NC}"
echo -e "  cd work"
echo -e "  vsim -c tb_nmp_alt_compressed -do \"run -all; quit\""
echo -e "\n${YELLOW}Or with GUI:${NC}"
echo -e "  cd work"
echo -e "  vsim tb_nmp_alt_compressed"
echo -e ""

