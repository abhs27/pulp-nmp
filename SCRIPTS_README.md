# PULPino Automation Scripts

This directory contains two powerful automation scripts to simplify the development workflow for PULPino RISC-V programs.

## Scripts Overview

### 1. `compile_program.sh` - Program Compiler
Automatically compiles C programs for the PULPino RISC-V processor.

**Usage:**
```bash
./compile_program.sh <program_name.c>
```

**Example:**
```bash
./compile_program.sh my_program.c
```

### 2. `run_simulation.sh` - Simulation Runner  
Automatically runs ModelSim simulation for compiled programs.

**Usage:**
```bash
./run_simulation.sh <program_name> [simulation_time]
```

**Examples:**
```bash
./run_simulation.sh my_program           # Default 2ms simulation
./run_simulation.sh my_program 5ms       # 5ms simulation
```

## Quick Start Workflow

1. Create your C program (e.g., my_program.c)
2. Run: `./compile_program.sh my_program.c`
3. Run: `./run_simulation.sh my_program`
4. View UART output automatically displayed

Both scripts include comprehensive error handling and colored output for better user experience.
