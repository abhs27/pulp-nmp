#!/bin/bash

# PULPino Program Compiler Script
# Usage: ./compile_program.sh <program_name.c>
# Example: ./compile_program.sh my_program.c

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
    echo "Usage: $0 <program_name.c>"
    echo "Example: $0 my_program.c"
    exit 1
fi

# Get program name and extract base name (without .c extension)
PROGRAM_FILE="$1"
PROGRAM_NAME=$(basename "$PROGRAM_FILE" .c)

print_status "Starting compilation process for: $PROGRAM_NAME"

# Check if we're in the correct directory (should contain sw folder)
if [ ! -d "sw" ]; then
    print_error "Not in PULPino root directory! Please run this script from the pulpino directory."
    exit 1
fi

# Set up environment
export PATH="/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH"

# Check if RISC-V toolchain is available
if ! command -v riscv32-unknown-elf-gcc &> /dev/null; then
    print_error "RISC-V toolchain not found in PATH!"
    exit 1
fi

# Create program directory
PROGRAM_DIR="sw/apps/$PROGRAM_NAME"
print_status "Creating program directory: $PROGRAM_DIR"
mkdir -p "$PROGRAM_DIR"

# Check if the source file exists in the program directory
if [ ! -f "$PROGRAM_DIR/$PROGRAM_FILE" ]; then
    if [ -f "$PROGRAM_FILE" ]; then
        # Copy from current directory
        print_status "Copying $PROGRAM_FILE to $PROGRAM_DIR/"
        cp "$PROGRAM_FILE" "$PROGRAM_DIR/"
    else
        print_error "Source file $PROGRAM_FILE not found!"
        print_warning "Please ensure the C file exists in the current directory or in $PROGRAM_DIR/"
        exit 1
    fi
fi

# Create CMakeLists.txt for the program
print_status "Creating CMakeLists.txt for $PROGRAM_NAME"
cat > "$PROGRAM_DIR/CMakeLists.txt" << EOFCMAKE
add_application($PROGRAM_NAME $PROGRAM_FILE)
EOFCMAKE

# Check if program is already added to main CMakeLists.txt
MAIN_CMAKE="sw/apps/CMakeLists.txt"
if grep -q "add_subdirectory($PROGRAM_NAME)" "$MAIN_CMAKE"; then
    print_warning "Program $PROGRAM_NAME already exists in main CMakeLists.txt"
else
    print_status "Adding $PROGRAM_NAME to main CMakeLists.txt"
    echo "add_subdirectory($PROGRAM_NAME)" >> "$MAIN_CMAKE"
fi

# Navigate to build directory
print_status "Navigating to build directory"
cd sw/build

# Configure cmake
print_status "Configuring CMake build system..."
if ./cmake_configure.riscv.gcc.sh > cmake_config.log 2>&1; then
    print_success "CMake configuration completed successfully"
else
    print_error "CMake configuration failed!"
    echo "Check cmake_config.log for details"
    exit 1
fi

# Compile the program
print_status "Compiling $PROGRAM_NAME..."
if make "$PROGRAM_NAME" > compile.log 2>&1; then
    print_success "Program $PROGRAM_NAME compiled successfully!"
else
    print_error "Compilation failed!"
    echo "Check compile.log for details"
    tail -20 compile.log
    exit 1
fi

# Check if binary files were generated
PROGRAM_BUILD_DIR="apps/$PROGRAM_NAME"
if [ -f "$PROGRAM_BUILD_DIR/$PROGRAM_NAME.elf" ] && [ -f "$PROGRAM_BUILD_DIR/$PROGRAM_NAME.bin" ]; then
    print_success "Generated files:"
    ls -la "$PROGRAM_BUILD_DIR"/*.elf "$PROGRAM_BUILD_DIR"/*.bin "$PROGRAM_BUILD_DIR"/*.s19 2>/dev/null || true
else
    print_error "Binary files were not generated properly"
    exit 1
fi

# Check if memory files were generated
if [ -d "$PROGRAM_BUILD_DIR/slm_files" ] && [ "$(ls -A $PROGRAM_BUILD_DIR/slm_files)" ]; then
    print_success "Memory files generated in $PROGRAM_BUILD_DIR/slm_files/"
    ls -la "$PROGRAM_BUILD_DIR/slm_files/"
else
    print_warning "Memory files not found or empty"
fi

cd ../..  # Return to root directory

print_success "Compilation process completed successfully!"
echo ""
print_status "To run the simulation, use:"
echo "./run_simulation.sh $PROGRAM_NAME"
