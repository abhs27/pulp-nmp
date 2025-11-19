@echo off
REM -----------------------------------------------------------------------------
REM Compilation Script for the Full NMP Module
REM Compiles all RTL source files required for the top-level NMP.
REM Uses ModelSim/QuestaSim vlog compiler.
REM -----------------------------------------------------------------------------

echo ============================================================
echo      NMP Full Module Compilation Script
echo ============================================================

setlocal

set RTL_DIR=rtl_nmp
set VLOG_OPTS=-work work

REM --- Setup ---
REM Create work directory if it doesn't exist
if not exist "work" (
    echo Creating work directory...
    vlib work
)

REM --- Compilation ---
echo.
echo Step 1: Compiling leaf modules...
vlog %VLOG_OPTS% %RTL_DIR%\multiplier.sv
if errorlevel 1 ( echo [ERROR] Failed to compile multiplier.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\divider.sv
if errorlevel 1 ( echo [ERROR] Failed to compile divider.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_addr_gen.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_addr_gen.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_decoder_hash.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_decoder_hash.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_address_lookup_table.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_address_lookup_table.sv & exit /b 1 )

echo [SUCCESS] Leaf modules compiled.

echo.
echo Step 2: Compiling mid-level modules...
vlog %VLOG_OPTS% %RTL_DIR%\nmp_alu.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_alu.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_hash_addr_decoder.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_hash_addr_decoder.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_fsm_hash.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_fsm_hash.sv & exit /b 1 )

vlog %VLOG_OPTS% %RTL_DIR%\nmp_axi_master.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_axi_master.sv & exit /b 1 )

echo [SUCCESS] Mid-level modules compiled.

echo.
echo Step 3: Compiling top-level NMP module...
vlog %VLOG_OPTS% %RTL_DIR%\nmp_top_hash.sv
if errorlevel 1 ( echo [ERROR] Failed to compile nmp_top_hash.sv & exit /b 1 )

echo [SUCCESS] Top-level NMP module compiled.

echo.

echo ============================================================
echo [SUCCESS] Full NMP Module Compilation Complete!
echo ============================================================
echo.
echo To simulate a testbench (e.g., tb_nmp_comprehensive):
echo   vlog -work work tests_nmp\tb_nmp_comprehensive.sv
echo   vsim -c tb_nmp_comprehensive -do "run -all; quit"
echo.

endlocal
