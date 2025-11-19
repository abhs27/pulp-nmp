# NMP Project: Quick Start Guide

This guide provides the essential information to set up your environment, compile the NMP module, and run the verification test suite.

## ALU Specs
- The entire ALU is 32-bit Integer, no floating point
- addition and subtraction are single cycle
- multiplication is a 4 stage pipeline, but the NMP ALU is not designed to take advantage of this pipelining, so the latency for a every single multiplication is 4 cycles.
- divider using non-restoring division algorithm, 32 cycles latency for each division.


## Directory Structure

The project is organized into the following key directories:

*   `rtl_nmp/`: Contains all the SystemVerilog source files for the NMP module and its sub-modules (ALU, FSM, decoder, etc.).
*   `tests_nmp/`: Contains all the testbench files used to verify the functionality of the NMP modules.
*   `bin/`: This directory is created by the test scripts and contains the compiled executables for each test.
*   `simulations/`: This directory is created by some testbenches and holds waveform dump files (`.vcd`) and other simulation artifacts.
*   `work/`: This directory is created by the compilation scripts and is the library where ModelSim/QuestaSim stores compiled design units.

## 1. Tool Installation

To compile and test the NMP, you will need two main tools:
1.  An open-source Verilog simulator like **Icarus Verilog**.
2.  A waveform viewer like **GTKWave**.

### For Linux (Debian/Ubuntu)

Open a terminal and run the following command:
```bash
sudo apt-get update && sudo apt-get install iverilog gtkwave
```

### For Windows

You can download pre-compiled binaries from the official sources:
*   **Icarus Verilog:** Visit the [iverilog-v12 branch builds page](http://bleyer.org/icarus/latest/) and download the latest `x64` build. Run the installer and ensure that the installation path is added to your system's `PATH` environment variable.
*   **GTKWave:** Visit the [GTKWave SourceForge page](https://gtkwave.sourceforge.net/) and download the latest `win64` installer. Run the installer.

## 2. Running the Full Test Suite

The easiest way to verify the entire NMP design is to run the comprehensive test suite script. This script compiles all the individual unit tests and the top-level integration test, then executes them sequentially.

Open a command prompt or terminal, navigate to the project's root directory, and run:
```bash
run_all_tests.bat
```
This script will print the status of each test as it runs. Any test failures will be clearly marked with `[ERROR]` or `[FAIL]`.

## 3. Compiling the NMP Module (Manual)

If you wish to compile the full NMP design manually (without running the tests), you can use the provided compilation script. This is useful for checking for syntax errors or preparing for a custom simulation.

Open a command prompt or terminal and run:
```bash
compile_nmp_full.bat
```
This script compiles all SystemVerilog source files from the `rtl_nmp/` directory into a library named `work`.

## 4. Viewing Waveforms

Several of the unit tests (e.g., `mul_tb.sv`, `div_tb.sv`) generate a waveform dump file (`.vcd`) in the project's root directory. For example, after running `run_all_tests.bat`, you will find `pipelined_fma.vcd` and `divider.vcd`.

To view these waveforms, open GTKWave and load the desired `.vcd` file.

## 5. Documentation

NMP architecture implementation details are specified in the NMP_architecture.md file
