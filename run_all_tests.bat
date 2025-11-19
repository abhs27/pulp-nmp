@echo off
setlocal

:: ============================================================================
:: NMP Comprehensive Test Suite Runner
:: ============================================================================
:: This script compiles and runs all unit and integration tests for the NMP.
:: It uses Icarus Verilog (iverilog) to compile and vvp to execute.
:: ============================================================================

title NMP Test Runner

:: --- Configuration ---
set RTL_DIR=rtl_nmp
set TEST_DIR=tests_nmp
set OUT_DIR=bin
set IVERILOG_FLAGS=-g2012 -Wimplicit

:: --- Setup ---
echo.
echo [SETUP] Creating output directory for compiled tests...
if not exist %OUT_DIR% mkdir %OUT_DIR%
echo.

:: --- Test Execution ---
echo =================================================
echo           STARTING NMP TEST SUITE
echo =================================================
echo.

:: 1. Multiplier Unit Test (Existing)
echo [TEST 1/11] Running Multiplier Unit Test (mul_tb.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/mul_test.vvp %RTL_DIR%/multiplier.sv %TEST_DIR%/mul_tb.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/mul_test.vvp
echo.

:: 2. Divider Unit Test (Existing)
echo [TEST 2/11] Running Divider Unit Test (div_tb.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/div_test.vvp %RTL_DIR%/divider.sv %TEST_DIR%/div_tb.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/div_test.vvp
echo.

:: 3. Hash Generator Unit Test
echo [TEST 3/11] Running Hash Generator Unit Test (tb_nmp_hash_generator.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/hash_gen_test.vvp %RTL_DIR%/nmp_hash_generator.sv %TEST_DIR%/tb_nmp_hash_generator.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/hash_gen_test.vvp
echo.

:: 4. Address Generator Unit Test
echo [TEST 4/11] Running Address Generator Unit Test (tb_nmp_addr_gen.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/addr_gen_test.vvp %RTL_DIR%/nmp_addr_gen.sv %TEST_DIR%/tb_nmp_addr_gen.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/addr_gen_test.vvp
echo.

:: 5. Instruction Decoder Unit Test
echo [TEST 5/11] Running Instruction Decoder Unit Test (tb_nmp_decoder_hash.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/decoder_test.vvp %RTL_DIR%/nmp_decoder_hash.sv %TEST_DIR%/tb_nmp_decoder_hash.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/decoder_test.vvp
echo.

:: 6. Address Lookup Table (ALT) Unit Test
echo [TEST 6/11] Running Address Lookup Table Unit Test (tb_nmp_address_lookup_table.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/alt_test.vvp %RTL_DIR%/nmp_address_lookup_table.sv %TEST_DIR%/tb_nmp_address_lookup_table.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/alt_test.vvp
echo.

:: 7. Hash Address Decoder Unit Test
echo [TEST 7/11] Running Hash Address Decoder Unit Test (tb_nmp_hash_addr_decoder.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/hash_decoder_test.vvp %RTL_DIR%/nmp_hash_addr_decoder.sv %TEST_DIR%/tb_nmp_hash_addr_decoder.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/hash_decoder_test.vvp
echo.

:: 8. ALU Unit Test
echo [TEST 8/11] Running ALU Unit Test (tb_nmp_alu.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/alu_test.vvp %RTL_DIR%/nmp_alu.sv %RTL_DIR%/multiplier.sv %RTL_DIR%/divider.sv %TEST_DIR%/tb_nmp_alu.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/alu_test.vvp
echo.

:: 9. FSM Unit Test
echo [TEST 9/11] Running FSM Unit Test (tb_nmp_fsm.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/fsm_test.vvp %RTL_DIR%/nmp_fsm_hash.sv %TEST_DIR%/tb_nmp_fsm.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/fsm_test.vvp
echo.

:: 10. AXI Master Unit Test
echo [TEST 10/11] Running AXI Master Unit Test (tb_nmp_axi_master.sv)...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/axi_master_test.vvp %RTL_DIR%/nmp_axi_master.sv %TEST_DIR%/tb_nmp_axi_master.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/axi_master_test.vvp
echo.

:: 11. Comprehensive Top-Level Test
echo [TEST 11/11] Running Comprehensive Top-Level Integration Test...
iverilog %IVERILOG_FLAGS% -o %OUT_DIR%/comprehensive_test.vvp %RTL_DIR%/*.sv %TEST_DIR%/tb_nmp_comprehensive.sv
if %errorlevel% neq 0 ( echo   [ERROR] Compilation failed. & goto :end )
vvp %OUT_DIR%/comprehensive_test.vvp
echo.


:end
echo =================================================
echo           NMP TEST SUITE FINISHED
echo =================================================
echo.

endlocal
