#!/bin/bash

# Results Aggregator Script for Azure Multi-Region Latency Testing
# This script processes and compares latency results across all tested regions

set -e

# Configuration
RESULTS_DIR="test-results"
AGGREGATED_DIR="aggregated-results"
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to extract latency from result file
extract_latency() {
    local file=$1
    if [ -f "$file" ]; then
        grep -oP 'Average latency: \K[\d.]+' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to extract detailed metrics
extract_metrics() {
    local file=$1
    local metrics=()
    
    if [ -f "$file" ]; then
        # Extract various metrics
        metrics+=("$(grep -oP 'Data fetch: \K[\d.]+' "$file" 2>/dev/null || echo 'N/A')")
        metrics+=("$(grep -oP 'Calculation: \K[\d.]+' "$file" 2>/dev/null || echo 'N/A')")
        metrics+=("$(grep -oP 'Params calculation: \K[\d.]+' "$file" 2>/dev/null || echo 'N/A')")
        metrics+=("$(grep -oP 'Order placement: \K[\d.]+' "$file" 2>/dev/null || echo 'N/A')")
        metrics+=("$(grep -oP 'Successful orders: \K[\d]+' "$file" 2>/dev/null || echo '0')")
        metrics+=("$(grep -oP 'Failed orders: \K[\d]+' "$file" 2>/dev/null || echo '0')")
    else
        metrics=("N/A" "N/A" "N/A" "N/A" "0" "0")
    fi
    
    printf '%s\n' "${metrics[@]}"
}

# Function to create comprehensive results report
create_results_report() {
    local output_file="$AGGREGATED_DIR/LATENCY_RESULTS_${TIMESTAMP}.md"
    
    print_status $BLUE "Creating comprehensive results report..."
    
    # Create aggregated directory
    mkdir -p "$AGGREGATED_DIR"
    
    # Start building the report
    cat > "$output_file" << EOF
# Azure Multi-Region Latency Test Results

**Test Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Report Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Total Regions Analyzed:** $(find "$RESULTS_DIR" -name "*.txt" 2>/dev/null | wc -l)

## Executive Summary

This report provides a comprehensive analysis of latency performance across Azure regions for Hyperliquid trading operations.

EOF

    # Collect all region results
    local regions=()
    local latencies=()
    local region_files=()
    
    for result_file in "$RESULTS_DIR"/*.txt; do
        if [ -f "$result_file" ]; then
            local region=$(basename "$result_file" .txt)
            local latency=$(extract_latency "$result_file")
            
            regions+=("$region")
            latencies+=("$latency")
            region_files+=("$result_file")
        fi
    done
    
    # Sort regions by latency (simple numeric sort)
    local sorted_indices=()
    for i in "${!latencies[@]}"; do
        sorted_indices+=("$i")
    done
    
    # Simple bubble sort by latency
    for ((i=0; i<${#latencies[@]}-1; i++)); do
        for ((j=0; j<${#latencies[@]}-i-1; j++)); do
            if (( $(echo "${latencies[${sorted_indices[j]}]} > ${latencies[${sorted_indices[j+1]}]}" | bc -l) )); then
                local temp=${sorted_indices[j]}
                sorted_indices[j]=${sorted_indices[j+1]}
                sorted_indices[j+1]=$temp
            fi
        done
    done
    
    # Add results summary table
    cat >> "$output_file" << EOF

## Results Summary (Fastest to Slowest)

| Rank | Region | Average Latency (ms) | Status |
|------|--------|---------------------|--------|
EOF

    local rank=1
    for i in "${sorted_indices[@]}"; do
        local region="${regions[i]}"
        local latency="${latencies[i]}"
        local status="✓ Success"
        
        if (( $(echo "$latency == 0" | bc -l) )); then
            status="✗ Failed"
        elif (( $(echo "$latency > 1000" | bc -l) )); then
            status="⚠ High Latency"
        fi
        
        echo "| $rank | $region | $latency | $status |" >> "$output_file"
        ((rank++))
    done
    
    # Add performance analysis
    cat >> "$output_file" << EOF

## Performance Analysis

### Latency Distribution

EOF

    # Calculate statistics
    local total_latency=0
    local valid_latencies=()
    
    for latency in "${latencies[@]}"; do
        if (( $(echo "$latency > 0 && $latency < 1000" | bc -l) )); then
            valid_latencies+=("$latency")
            total_latency=$(echo "$total_latency + $latency" | bc -l)
        fi
    done
    
    if [ ${#valid_latencies[@]} -gt 0 ]; then
        local avg_latency=$(echo "scale=2; $total_latency / ${#valid_latencies[@]}" | bc -l)
        local min_latency=$(printf '%s\n' "${valid_latencies[@]}" | sort -n | head -1)
        local max_latency=$(printf '%s\n' "${valid_latencies[@]}" | sort -n | tail -1)
        
        cat >> "$output_file" << EOF
- **Average Latency:** ${avg_latency} ms
- **Minimum Latency:** ${min_latency} ms
- **Maximum Latency:** ${max_latency} ms
- **Successful Regions:** ${#valid_latencies[@]}
- **Failed Regions:** $((${#regions[@]} - ${#valid_latencies[@]}))

### Top 5 Fastest Regions

EOF

        rank=1
        for i in "${sorted_indices[@]}"; do
            if [ $rank -le 5 ]; then
                local region="${regions[i]}"
                local latency="${latencies[i]}"
                if (( $(echo "$latency > 0 && $latency < 1000" | bc -l) )); then
                    echo "$rank. **$region**: ${latency} ms" >> "$output_file"
                    ((rank++))
                fi
            fi
        done
        
        cat >> "$output_file" << EOF

### Recommendations

Based on the latency analysis:

1. **Primary Recommendation:** Use **${regions[${sorted_indices[0]}]}** for lowest latency (${latencies[${sorted_indices[0]}]} ms)
2. **Secondary Options:** Consider ${regions[${sorted_indices[1]}]} and ${regions[${sorted_indices[2]}]} as backup regions
3. **Avoid:** Regions with latency > 500ms for high-frequency trading

EOF
    else
        cat >> "$output_file" << EOF
- **No valid latency data found**
- **All regions failed testing**

### Troubleshooting Required

All regions failed the latency test. Please check:
1. Network connectivity
2. Azure service availability
3. Hyperliquid API status
4. Redis connection
5. Private key configuration

EOF
    fi
    
    # Add detailed results for each region
    cat >> "$output_file" << EOF

## Detailed Results by Region

EOF

    for i in "${sorted_indices[@]}"; do
        local region="${regions[i]}"
        local latency="${latencies[i]}"
        local result_file="${region_files[i]}"
        
        cat >> "$output_file" << EOF

### $region

**Average Latency:** ${latency} ms

EOF

        # Extract detailed metrics
        local metrics=($(extract_metrics "$result_file"))
        if [ "${metrics[0]}" != "N/A" ]; then
            cat >> "$output_file" << EOF
**Detailed Metrics:**
- Data Fetch: ${metrics[0]} ms
- Calculation: ${metrics[1]} ms  
- Params Calculation: ${metrics[2]} ms
- Order Placement: ${metrics[3]} ms
- Successful Orders: ${metrics[4]}
- Failed Orders: ${metrics[5]}

EOF
        fi
        
        # Add raw output
        cat >> "$output_file" << EOF
**Raw Output:**
\`\`\`
EOF
        if [ -f "$result_file" ]; then
            cat "$result_file" >> "$output_file"
        else
            echo "No output file found" >> "$output_file"
        fi
        cat >> "$output_file" << EOF
\`\`\`

EOF
    done
    
    # Add footer
    cat >> "$output_file" << EOF

---

*Report generated by Azure Multi-Region Latency Test System*
*For questions or issues, please check the GitHub Actions logs*
EOF

    print_status $GREEN "Results report created: $output_file"
    
    # Copy to latest results
    cp "$output_file" "$AGGREGATED_DIR/LATEST_RESULTS.md"
    print_status $GREEN "Latest results updated: $AGGREGATED_DIR/LATEST_RESULTS.md"
}

# Function to create CSV export
create_csv_export() {
    local csv_file="$AGGREGATED_DIR/latency_results_${TIMESTAMP}.csv"
    
    print_status $BLUE "Creating CSV export..."
    
    cat > "$csv_file" << EOF
Region,Average_Latency_ms,Data_Fetch_ms,Calculation_ms,Params_Calculation_ms,Order_Placement_ms,Successful_Orders,Failed_Orders,Status
EOF

    for result_file in "$RESULTS_DIR"/*.txt; do
        if [ -f "$result_file" ]; then
            local region=$(basename "$result_file" .txt)
            local latency=$(extract_latency "$result_file")
            local metrics=($(extract_metrics "$result_file"))
            
            local status="Success"
            if (( $(echo "$latency == 0" | bc -l) )); then
                status="Failed"
            elif (( $(echo "$latency > 1000" | bc -l) )); then
                status="High_Latency"
            fi
            
            echo "$region,$latency,${metrics[0]},${metrics[1]},${metrics[2]},${metrics[3]},${metrics[4]},${metrics[5]},$status" >> "$csv_file"
        fi
    done
    
    print_status $GREEN "CSV export created: $csv_file"
}

# Function to display summary
display_summary() {
    print_status $BLUE "=== LATENCY TEST SUMMARY ==="
    
    local total_files=$(find "$RESULTS_DIR" -name "*.txt" 2>/dev/null | wc -l)
    local successful_regions=0
    local failed_regions=0
    local total_latency=0
    
    for result_file in "$RESULTS_DIR"/*.txt; do
        if [ -f "$result_file" ]; then
            local latency=$(extract_latency "$result_file")
            if (( $(echo "$latency > 0 && $latency < 1000" | bc -l) )); then
                ((successful_regions++))
                total_latency=$(echo "$total_latency + $latency" | bc -l)
            else
                ((failed_regions++))
            fi
        fi
    done
    
    local avg_latency=0
    if [ $successful_regions -gt 0 ]; then
        avg_latency=$(echo "scale=2; $total_latency / $successful_regions" | bc -l)
    fi
    
    echo "Total Regions Tested: $total_files"
    echo "Successful Regions: $successful_regions"
    echo "Failed Regions: $failed_regions"
    echo "Average Latency: ${avg_latency} ms"
    
    if [ $successful_regions -gt 0 ]; then
        print_status $GREEN "✓ Testing completed successfully"
        
        # Find fastest region
        local fastest_region=""
        local fastest_latency=999999
        for result_file in "$RESULTS_DIR"/*.txt; do
            if [ -f "$result_file" ]; then
                local region=$(basename "$result_file" .txt)
                local latency=$(extract_latency "$result_file")
                if (( $(echo "$latency > 0 && $latency < $fastest_latency" | bc -l) )); then
                    fastest_latency=$latency
                    fastest_region=$region
                fi
            fi
        done
        
        print_status $GREEN "🏆 Fastest Region: $fastest_region (${fastest_latency} ms)"
    else
        print_status $RED "✗ All regions failed testing"
    fi
}

# Main execution
main() {
    print_status $BLUE "Azure Multi-Region Latency Test Results Aggregator"
    print_status $BLUE "=================================================="
    
    # Check if results directory exists
    if [ ! -d "$RESULTS_DIR" ]; then
        print_status $RED "Error: Results directory '$RESULTS_DIR' not found"
        print_status $YELLOW "Please run the latency tests first"
        exit 1
    fi
    
    # Check if there are any result files
    if [ $(find "$RESULTS_DIR" -name "*.txt" 2>/dev/null | wc -l) -eq 0 ]; then
        print_status $RED "Error: No result files found in '$RESULTS_DIR'"
        print_status $YELLOW "Please run the latency tests first"
        exit 1
    fi
    
    # Create aggregated directory
    mkdir -p "$AGGREGATED_DIR"
    
    # Generate all reports
    create_results_report
    create_csv_export
    
    # Display summary
    echo ""
    display_summary
    
    print_status $GREEN "All reports generated successfully!"
    print_status $BLUE "Files created:"
    echo "  - $AGGREGATED_DIR/LATENCY_RESULTS_${TIMESTAMP}.md"
    echo "  - $AGGREGATED_DIR/LATEST_RESULTS.md"
    echo "  - $AGGREGATED_DIR/latency_results_${TIMESTAMP}.csv"
}

# Run main function
main "$@"
