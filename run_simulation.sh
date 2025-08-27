#!/bin/bash

# PULPino Simulation Runner Script
# Usage: ./run_simulation.sh <program_name> [simulation_time]
# Example: ./run_simulation.sh my_program
# Example: ./run_simulation.sh my_program 5ms

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if argument is provided
if [ $# -eq 0 ]; then
    print_error "No program name provided!"
    echo "Usage: $0 <program_name> [simulation_time]"
    echo "Example: $0 my_program"
    echo "Example: $0 my_program 5ms"
    exit 1
fi

# Get program name and simulation time
PROGRAM_NAME="$1"
SIM_TIME="${2:-2ms}"  # Default to 2ms if not provided

print_status "Starting simulation for program: $PROGRAM_NAME"
print_status "Simulation time: $SIM_TIME"

# Check if we're in the correct directory (should contain sw and vsim folders)
if [ ! -d "sw" ] || [ ! -d "vsim" ]; then
    print_error "Not in PULPino root directory! Please run this script from the pulpino directory."
    exit 1
fi

# Set up environment
export PATH="/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH"

# Check if program build directory exists
PROGRAM_BUILD_DIR="sw/build/apps/$PROGRAM_NAME"
if [ ! -d "$PROGRAM_BUILD_DIR" ]; then
    print_error "Program build directory not found: $PROGRAM_BUILD_DIR"
    print_warning "Please compile the program first using: ./compile_program.sh $PROGRAM_NAME.c"
    exit 1
fi

# Check if binary files exist
if [ ! -f "$PROGRAM_BUILD_DIR/$PROGRAM_NAME.elf" ]; then
    print_error "Program binary not found: $PROGRAM_BUILD_DIR/$PROGRAM_NAME.elf"
    print_warning "Please compile the program first using: ./compile_program.sh $PROGRAM_NAME.c"
    exit 1
fi

# Check if memory files exist
SLM_SOURCE_DIR="$PROGRAM_BUILD_DIR/slm_files"
if [ ! -d "$SLM_SOURCE_DIR" ] || [ -z "$(ls -A $SLM_SOURCE_DIR)" ]; then
    print_error "Memory files not found in: $SLM_SOURCE_DIR"
    print_warning "Please recompile the program using: ./compile_program.sh $PROGRAM_NAME.c"
    exit 1
fi

# Navigate to vsim directory
print_status "Navigating to simulation directory"
cd vsim

# Create necessary directories
print_status "Creating necessary directories"
mkdir -p slm_files stdout

# Copy memory files
print_status "Copying memory files from $SLM_SOURCE_DIR to slm_files/"
cp ../$SLM_SOURCE_DIR/* slm_files/

print_status "Memory files copied:"
ls -la slm_files/

# Check if ModelSim is available
if ! command -v vsim &> /dev/null; then
    print_error "ModelSim (vsim) not found in PATH!"
    print_warning "Please ensure ModelSim is installed and in your PATH"
    exit 1
fi

# Set simulation environment variables
export TB_TEST="$PROGRAM_NAME"
export USE_ZERO_RISCY=0
export RISCY_RV32F=0
export ZERO_RV32M=0
export ZERO_RV32E=0

print_status "Simulation environment:"
echo "  TB_TEST: $TB_TEST"
echo "  USE_ZERO_RISCY: $USE_ZERO_RISCY"
echo "  RISCY_RV32F: $RISCY_RV32F"
echo "  ZERO_RV32M: $ZERO_RV32M"
echo "  ZERO_RV32E: $ZERO_RV32E"

# Run simulation
print_status "Starting ModelSim simulation..."
echo "Simulation command will run for $SIM_TIME"

# Create simulation log file
SIM_LOG="simulation_${PROGRAM_NAME}_$(date +%Y%m%d_%H%M%S).log"

print_status "Running simulation (this may take a few minutes)..."

# Run the simulation
if vsim -c -quiet tb \
    -L pulpino_lib -L adv_dbg_if_lib -L apb_event_unit_lib -L apb_fll_if_lib \
    -L apb_gpio_lib -L apb_i2c_lib -L apb_node_lib -L apb_pulpino_lib \
    -L apb_spi_master_lib -L apb_timer_lib -L apb_uart_lib -L apb_uart_sv_lib \
    -L apb2per_lib -L axi_mem_if_DP_lib -L axi_node_lib -L axi_slice_dc_lib \
    -L axi_slice_lib -L axi_spi_master_lib -L axi_spi_slave_lib -L axi2apb_lib \
    -L core2axi_lib -L fpu_lib -L riscv_lib -L zero_riscy_lib \
    +nowarnTRAN +nowarnTSCALE +nowarnTFMPC +MEMLOAD=PRELOAD \
    -gUSE_ZERO_RISCY=0 -gRISCY_RV32F=0 -gZERO_RV32M=0 -gZERO_RV32E=0 \
    -t ps -voptargs="+acc -suppress 2103" -GTEST="$PROGRAM_NAME" \
    -do "run $SIM_TIME; quit" > "$SIM_LOG" 2>&1; then
    
    print_success "Simulation completed successfully!"
else
    print_error "Simulation failed!"
    echo "Check $SIM_LOG for details"
    tail -20 "$SIM_LOG"
    cd ..
    exit 1
fi

# Check results
print_status "Simulation results:"

# Check if UART output was generated
if [ -f "stdout/uart" ] && [ -s "stdout/uart" ]; then
    print_success "UART Output:"
    echo "----------------------------------------"
    cat stdout/uart
    echo "----------------------------------------"
else
    print_warning "No UART output found or file is empty"
fi

# Check if execution trace was generated
if [ -f "trace_core_00_0.log" ]; then
    TRACE_SIZE=$(stat -c%s "trace_core_00_0.log" 2>/dev/null || echo "0")
    print_success "Execution trace generated: trace_core_00_0.log (${TRACE_SIZE} bytes)"
else
    print_warning "No execution trace found"
fi

# Check simulation log for specific patterns
print_status "Simulation summary:"
if grep -q "RX string:" "$SIM_LOG"; then
    print_success "Program output detected in simulation"
    echo "Program messages:"
    grep "RX string:" "$SIM_LOG" | sed 's/.*RX string: /  /' | head -20
elif grep -q "Test OK" "$SIM_LOG"; then
    print_success "Simulation completed with 'Test OK'"
elif grep -q "Errors: 0" "$SIM_LOG"; then
    print_success "Simulation completed with no errors"
else
    print_warning "Check simulation log for detailed results"
fi

# Show simulation statistics
if grep -q "End time:" "$SIM_LOG"; then
    ELAPSED_TIME=$(grep "Elapsed time:" "$SIM_LOG" | sed 's/.*Elapsed time: //')
    print_status "Simulation elapsed time: $ELAPSED_TIME"
fi

print_success "Simulation results available in:"
echo "  - UART output: stdout/uart"
echo "  - Execution trace: trace_core_00_0.log"
echo "  - Simulation log: $SIM_LOG"

cd ..  # Return to root directory

print_success "Simulation process completed!"
