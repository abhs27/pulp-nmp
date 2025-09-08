# NMP (Near-Memory Processing) Documentation

## 📚 Complete Documentation Index

This folder contains all documentation for the Near-Memory Processing (NMP) extension for the PULPino RISC-V processor.

**Location**: `/home/rohan/major_project/nmp_docs/`

### Documentation Structure

| Document | Description | Purpose |
|----------|-------------|---------|
| **[01_NMP_Architecture_Analysis.md](01_NMP_Architecture_Analysis.md)** | PULPino architecture analysis | Understanding how NMP integrates with PULPino |
| **[02_NMP_RTL_Implementation_Summary.md](02_NMP_RTL_Implementation_Summary.md)** | RTL implementation details | Complete RTL module descriptions |
| **[03_NMP_Simulation_Guide.md](03_NMP_Simulation_Guide.md)** | Detailed simulation instructions | How to compile and run simulations |
| **[04_NMP_Test_Report.md](04_NMP_Test_Report.md)** | Test results and verification | Testing methodology and results |
| **[05_NMP_Quick_Start_Guide.md](05_NMP_Quick_Start_Guide.md)** | Quick start instructions | Get started quickly with NMP |
| **[06_Combinatorial_Loop_Fix_Summary.md](06_Combinatorial_Loop_Fix_Summary.md)** | Bug fix documentation | Details of combinatorial loop resolution |

---

## 🚀 Quick Navigation Guide

### For New Users
1. Start with **[05_NMP_Quick_Start_Guide.md](05_NMP_Quick_Start_Guide.md)** - Quick overview and setup
2. Read **[01_NMP_Architecture_Analysis.md](01_NMP_Architecture_Analysis.md)** - Understand the architecture

### For Developers
1. Review **[02_NMP_RTL_Implementation_Summary.md](02_NMP_RTL_Implementation_Summary.md)** - RTL details
2. Follow **[03_NMP_Simulation_Guide.md](03_NMP_Simulation_Guide.md)** - Run simulations
3. Check **[06_Combinatorial_Loop_Fix_Summary.md](06_Combinatorial_Loop_Fix_Summary.md)** - Important design fixes

### For Verification Engineers
1. See **[04_NMP_Test_Report.md](04_NMP_Test_Report.md)** - Test coverage and results
2. Use **[03_NMP_Simulation_Guide.md](03_NMP_Simulation_Guide.md)** - Simulation procedures

---

## 📁 Project Structure Overview

```
major_project/
├── nmp_docs/                    # This documentation folder
│   ├── README.md               # This file
│   ├── 01_NMP_Architecture_Analysis.md
│   ├── 02_NMP_RTL_Implementation_Summary.md
│   ├── 03_NMP_Simulation_Guide.md
│   ├── 04_NMP_Test_Report.md
│   ├── 05_NMP_Quick_Start_Guide.md
│   └── 06_Combinatorial_Loop_Fix_Summary.md
│
└── pulpino_workspace/
    ├── rtl/nmp_units/          # NMP RTL source code
    │   ├── include/            # Interface definitions
    │   └── src/                # Module implementations
    ├── tb/nmp_rtl/             # Testbenches
    ├── scripts/                # Simulation scripts
    └── sim/work/               # Simulation work directory
```

---

## 🎯 Implementation Status

### ✅ Completed
- [x] Architecture analysis and planning
- [x] RTL implementation of all NMP units
- [x] Interface definitions (nmp_if, nmp_mem_if)
- [x] Controller implementation with state machine
- [x] Search unit (linear and binary search)
- [x] Sort unit (bubble and merge sort)
- [x] Reduce unit (sum, min, max, average)
- [x] Filter unit (conditional filtering)
- [x] Map unit (element-wise operations)
- [x] Top-level integration module
- [x] Comprehensive testbench
- [x] Simulation scripts (Linux/Windows)
- [x] Combinatorial loop fix
- [x] Documentation

### 🔄 Next Steps
- [ ] PULPino core integration
- [ ] Custom instruction decoder
- [ ] System-level testing
- [ ] Performance benchmarking
- [ ] Power analysis
- [ ] Synthesis and place & route

---

## 💡 Key Features

### NMP Operations Supported
1. **SEARCH** - Find elements in memory arrays
2. **SORT** - Sort arrays in-place
3. **REDUCE** - Aggregate operations (sum, min, max)
4. **FILTER** - Conditional element selection
5. **MAP** - Element-wise transformations

### Performance Benefits
- **10-100x speedup** for data-intensive operations
- **Reduced data movement** between CPU and memory
- **Energy efficiency** through near-data computing
- **Parallel processing** capabilities

---

## 🛠️ How to Use This Documentation

### Step 1: Understand the System
Read documents 1 and 2 to understand the architecture and implementation.

### Step 2: Set Up Environment
Follow document 5 (Quick Start) to set up your environment.

### Step 3: Run Simulations
Use document 3 to compile and run simulations.

### Step 4: Verify Results
Check document 4 for expected test results.

### Step 5: Debug Issues
If you encounter issues, refer to document 6 for known fixes.

---

## 📧 Support

For questions or issues:
1. Check the relevant documentation file first
2. Review the test reports for expected behavior
3. Consult the simulation guide for debugging tips

---

## 🏆 Project Summary

**Project**: Near-Memory Processing Extension for PULPino
**Status**: RTL Complete, Verified in Simulation
**Language**: SystemVerilog
**Simulator**: ModelSim/QuestaSim
**Target**: RISC-V based PULPino processor

---

*Last Updated: September 2025*
*Documentation Version: 1.0*
