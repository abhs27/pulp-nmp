I'll provide you with a complete step-by-step guide to create, compile, and run a new C program on the PULPino RISC-V processor simulation.

## Step-by-Step Guide: Creating and Running a New C Program

### Step 1: Set up the Environment

First, make sure you have the correct environment set up:
Command:-

    cd /home/rohan/major_project/pulpino_workspace/pulpino


Command:-

    export PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH


### Step 2: Create a New Program Directory

Let's create a new program called "my_program" as an example:
Command:-

    mkdir -p sw/apps/my_program


### Step 3: Create Your C Program

Create your main C file:
\home\rohan\major_project\pulpino_workspace\pulpino\sw\apps\my_program\my_program.c

    #include <stdio.h>

    int main()
    {
      printf("Welcome to my custom program!\n");
      
      // Simple calculation example
      int a = 10;
      int b = 20;
      int sum = a + b;
      
      printf("The sum of %d + %d = %d\n", a, b, sum);
      
      // Simple loop example
      printf("Counting from 1 to 5:\n");
      for(int i = 1; i <= 5; i++) {
          printf("Count: %d\n", i);
      }
    
      printf("Program completed successfully!\n");
      return 0;
    }

### Step 4: Create a CMakeLists.txt File

This tells the build system about your program:
\home\rohan\major_project\pulpino_workspace\pulpino\sw\apps\my_program\CMakeLists.txt
  
    add_application(YOUR_PROGRAM_NAME YOUR_PROGRAM_NAME.c)

### Step 5: Update the Main Apps CMakeLists.txt

Add your new program to the main apps CMakeLists.txt:
And Add this line to it:-

    add_subdirectory(YOUR_PROGRAM_NAME)

  Or Use this command:-

    echo "add_subdirectory(YOUR_PROGRAM_NAME)" >> sw/apps/CMakeLists.txt


### Step 6: Navigate to Build Directory and Configure
Command 'cd sw/build' completed with exit code 0:


Reconfigure cmake to include the new program:
\
Command:-

    cd sw/build
    PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH ./cmake_configure.riscv.gcc.sh



### Step 7: Compile Your Program
Command:-

    PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH make YOUR_PROGRAM_NAME

### Step 8: Prepare for Simulation

Copy the generated memory files to the vsim directory:

    cd ../../vsim
    cp ../sw/build/apps/YOUR_PROGRAM_NAME/slm_files/* slm_files/


### Step 9: Run the Simulation
Command :-

    PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH TB_TEST="YOUR_PROGRAM_NAME" USE_ZERO_RISCY=0 RISCY_RV32F=0 ZERO_RV32M=0 ZERO_RV32E=0 vsim -c -quiet tb -L pulpino_lib -L adv_dbg_if_lib -L apb_event_unit_lib -L apb_fll_if_lib -L apb_gpio_lib -L apb_i2c_lib -L apb_node_lib -L apb_pulpino_lib -L apb_spi_master_lib -L apb_timer_lib -L apb_uart_lib -L apb_uart_sv_lib -L apb2per_lib -L axi_mem_if_DP_lib -L axi_node_lib -L axi_slice_dc_lib -L axi_slice_lib -L axi_spi_master_lib -L axi_spi_slave_lib -L axi2apb_lib -L core2axi_lib -L fpu_lib -L riscv_lib -L zero_riscy_lib +nowarnTRAN +nowarnTSCALE +nowarnTFMPC +MEMLOAD=PRELOAD -gUSE_ZERO_RISCY=0 -gRISCY_RV32F=0 -gZERO_RV32M=0 -gZERO_RV32E=0 -t ps -voptargs="+acc -suppress 2103" -GTEST="YOUR_PROGRAM_NAME" -do "run 2ms; quit"

### Step 10: Check Results

UART Output: 

    cat stdout/uart

    Execution Trace: ls -la trace_core_00_0.log
    
    Simulation Log: Check the console output for "RX string:" messages



---

## Complete Step-by-Step Guide Summary

### **Prerequisites:**
1. Ensure your environment is set up (RISC-V toolchain in PATH)
2. Make sure ModelSim and all IP libraries are compiled

### **Step 1: Set Environment Variables**
cd /home/rohan/major_project/pulpino_workspace/pulpino
export PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH
### **Step 2: Create Program Directory**
mkdir -p sw/apps/YOUR_PROGRAM_NAME
### **Step 3: Create Your C Program**
Create `sw/apps/YOUR_PROGRAM_NAME/YOUR_PROGRAM_NAME.c`:
#include <stdio.h>

int main()
{
    printf("Your program output here\n");
    // Your code here
    return 0;
}
### **Step 4: Create CMakeLists.txt**
Create `sw/apps/YOUR_PROGRAM_NAME/CMakeLists.txt`:
add_application(YOUR_PROGRAM_NAME YOUR_PROGRAM_NAME.c)
### **Step 5: Add to Main CMakeLists**
echo "add_subdirectory(YOUR_PROGRAM_NAME)" >> sw/apps/CMakeLists.txt
### **Step 6: Configure Build System**
cd sw/build
PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH ./cmake_configure.riscv.gcc.sh
### **Step 7: Compile Your Program**
PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH make YOUR_PROGRAM_NAME
### **Step 8: Prepare Simulation Files**
cd ../../vsim
cp ../sw/build/apps/YOUR_PROGRAM_NAME/slm_files/* slm_files/
### **Step 9: Run Simulation**
PATH=/tmp/riscv-override:/home/rohan/major_project/pulpino_workspace/riscv32-unknown-elf.gcc-13.2.0/bin:$PATH TB_TEST="YOUR_PROGRAM_NAME" USE_ZERO_RISCY=0 RISCY_RV32F=0 ZERO_RV32M=0 ZERO_RV32E=0 vsim -c -quiet tb -L pulpino_lib -L adv_dbg_if_lib -L apb_event_unit_lib -L apb_fll_if_lib -L apb_gpio_lib -L apb_i2c_lib -L apb_node_lib -L apb_pulpino_lib -L apb_spi_master_lib -L apb_timer_lib -L apb_uart_lib -L apb_uart_sv_lib -L apb2per_lib -L axi_mem_if_DP_lib -L axi_node_lib -L axi_slice_dc_lib -L axi_slice_lib -L axi_spi_master_lib -L axi_spi_slave_lib -L axi2apb_lib -L core2axi_lib -L fpu_lib -L riscv_lib -L zero_riscy_lib +nowarnTRAN +nowarnTSCALE +nowarnTFMPC +MEMLOAD=PRELOAD -gUSE_ZERO_RISCY=0 -gRISCY_RV32F=0 -gZERO_RV32M=0 -gZERO_RV32E=0 -t ps -voptargs="+acc -suppress 2103" -GTEST="YOUR_PROGRAM_NAME" -do "run 2ms; quit"
### **Step 10: Check Results**
- **UART Output:** `cat stdout/uart`
- **Execution Trace:** `ls -la trace_core_00_0.log`
- **Simulation Log:** Check the console output for "RX string:" messages

### **Available Libraries:**
You can include various headers in your C programs:
- `#include <stdio.h>` - Standard I/O (printf, etc.)
- `#include <stdlib.h>` - Standard library functions
- `#include <string.h>` - String manipulation
- `#include <math.h>` - Mathematical functions

### **Tips for Writing Programs:**
1. **Keep programs simple** - Complex programs may take longer to simulate
2. **Use printf() for output** - This will appear in the UART output
3. **Avoid infinite loops** - The simulation runs for a fixed time
4. **Test incrementally** - Start with simple programs and add complexity
5. **Check compilation errors** - Fix any compiler warnings/errors before simulation

### **Troubleshooting:**
- If compilation fails, check your C syntax
- If simulation doesn't show output, ensure memory files are copied correctly
- If simulation takes too long, reduce complexity or simulation time
- Check `trace_core_00_0.log` for detailed execution information

This process will work for any C program you want to run on the PULPino RISC-V processor!