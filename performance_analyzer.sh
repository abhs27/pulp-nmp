#!/bin/bash

#-----------------------------------------------------------------------------
# NMP Performance Analysis Script
# Analyzes simulation logs and extracts performance metrics
#-----------------------------------------------------------------------------

# Default log file
LOG_FILE="simulation_output_*.log"
REPORT_FILE="nmp_performance_analysis.txt"

echo "========================================================================"
echo "NMP Performance Analysis Tool"
echo "========================================================================"

# Function to analyze performance from log files
analyze_performance() {
    local logfile=$1
    echo "Analyzing performance from: $logfile"
    echo ""
    
    # Extract performance metrics
    if grep -q "PERFORMANCE REPORT" "$logfile"; then
        echo "=== EXTRACTED PERFORMANCE METRICS ===" > $REPORT_FILE
        echo "Analysis Date: $(date)" >> $REPORT_FILE
        echo "Source Log: $logfile" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        
        # Extract the performance report section
        sed -n '/PERFORMANCE REPORT/,/╚═══════════════════/p' "$logfile" >> $REPORT_FILE
        
        # Extract specific metrics
        echo "" >> $REPORT_FILE
        echo "=== KEY PERFORMANCE INDICATORS ===" >> $REPORT_FILE
        
        IPC=$(grep "Instructions Per Cycle" "$logfile" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        OPS_PER_CYCLE=$(grep "Operations Per Cycle" "$logfile" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        EFFICIENCY=$(grep "Execution Efficiency" "$logfile" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        MEM_UTIL=$(grep "Memory Bandwidth Util" "$logfile" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        
        if [ ! -z "$IPC" ]; then
            echo "Instructions Per Cycle (IPC): $IPC" >> $REPORT_FILE
            if (( $(echo "$IPC > 0.5" | bc -l) )); then
                echo "  Status: GOOD (>0.5)" >> $REPORT_FILE
            else
                echo "  Status: NEEDS IMPROVEMENT (<0.5)" >> $REPORT_FILE
            fi
        fi
        
        if [ ! -z "$OPS_PER_CYCLE" ]; then
            echo "Operations Per Cycle: $OPS_PER_CYCLE" >> $REPORT_FILE
        fi
        
        if [ ! -z "$EFFICIENCY" ]; then
            echo "Execution Efficiency: $EFFICIENCY%" >> $REPORT_FILE
            if (( $(echo "$EFFICIENCY > 70" | bc -l) )); then
                echo "  Status: GOOD (>70%)" >> $REPORT_FILE
            else
                echo "  Status: NEEDS OPTIMIZATION (<70%)" >> $REPORT_FILE
            fi
        fi
        
        if [ ! -z "$MEM_UTIL" ]; then
            echo "Memory Bandwidth Utilization: $MEM_UTIL%" >> $REPORT_FILE
        fi
        
        echo "" >> $REPORT_FILE
        echo "=== RECOMMENDATIONS ===" >> $REPORT_FILE
        
        if [ ! -z "$IPC" ] && (( $(echo "$IPC < 0.5" | bc -l) )); then
            echo "- Low IPC detected. Consider pipeline optimization." >> $REPORT_FILE
        fi
        
        if [ ! -z "$EFFICIENCY" ] && (( $(echo "$EFFICIENCY < 70" | bc -l) )); then
            echo "- Low execution efficiency. Review idle cycles and state machine." >> $REPORT_FILE
        fi
        
        echo "" >> $REPORT_FILE
        cat $REPORT_FILE
        
        echo ""
        echo "Performance analysis saved to: $REPORT_FILE"
        
    else
        echo "No performance report found in $logfile"
        echo "Make sure you ran the enhanced simulation script."
    fi
}

# Main execution
if [ $# -eq 1 ]; then
    # Specific log file provided
    if [ -f "$1" ]; then
        analyze_performance "$1"
    else
        echo "Error: File $1 not found!"
        exit 1
    fi
else
    # Look for the most recent log file
    LATEST_LOG=$(ls -t simulation_output_*.log 2>/dev/null | head -1)
    
    if [ ! -z "$LATEST_LOG" ]; then
        analyze_performance "$LATEST_LOG"
    else
        echo "No simulation log files found!"
        echo "Usage: $0 [logfile]"
        echo "   or run simulation first with: ./compile_nmp_enhanced.sh"
        exit 1
    fi
fi

echo "========================================================================"
