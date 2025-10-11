#!/bin/bash

# Azure Regions Management Script for Latency Testing
# This script provides utilities for managing Azure region testing

set -e

# Comprehensive list of Azure regions (as of 2024)
# Using a simple approach compatible with older bash versions
get_region_name() {
    case "$1" in
        # North America
        "eastus") echo "East US" ;;
        "eastus2") echo "East US 2" ;;
        "westus") echo "West US" ;;
        "westus2") echo "West US 2" ;;
        "westus3") echo "West US 3" ;;
        "centralus") echo "Central US" ;;
        "northcentralus") echo "North Central US" ;;
        "southcentralus") echo "South Central US" ;;
        "westcentralus") echo "West Central US" ;;
        "canadacentral") echo "Canada Central" ;;
        "canadaeast") echo "Canada East" ;;
        
        # Europe
        "northeurope") echo "North Europe" ;;
        "westeurope") echo "West Europe" ;;
        "uksouth") echo "UK South" ;;
        "ukwest") echo "UK West" ;;
        "francecentral") echo "France Central" ;;
        "francesouth") echo "France South" ;;
        "germanynorth") echo "Germany North" ;;
        "germanywestcentral") echo "Germany West Central" ;;
        "switzerlandnorth") echo "Switzerland North" ;;
        "switzerlandwest") echo "Switzerland West" ;;
        "norwayeast") echo "Norway East" ;;
        "norwaywest") echo "Norway West" ;;
        "swedencentral") echo "Sweden Central" ;;
        "swedensouth") echo "Sweden South" ;;
        "polandcentral") echo "Poland Central" ;;
        "italynorth") echo "Italy North" ;;
        "austriaeast") echo "Austria East" ;;
        "belgiumcentral") echo "Belgium Central" ;;
        "czechrepubliccentral") echo "Czech Republic Central" ;;
        "denmarkeast") echo "Denmark East" ;;
        "finlandcentral") echo "Finland Central" ;;
        "greecenorth") echo "Greece North" ;;
        "hungarycentral") echo "Hungary Central" ;;
        "irelandnorth") echo "Ireland North" ;;
        "latvialcentral") echo "Latvia Central" ;;
        "lithuaniasouth") echo "Lithuania South" ;;
        "luxembourgnorth") echo "Luxembourg North" ;;
        "maltaintermediate") echo "Malta Intermediate" ;;
        "netherlandsnorth") echo "Netherlands North" ;;
        "portugalcentral") echo "Portugal Central" ;;
        "sloveniawest") echo "Slovenia West" ;;
        "slovakiacentral") echo "Slovakia Central" ;;
        "spaincentral") echo "Spain Central" ;;
        
        # Asia Pacific
        "eastasia") echo "East Asia" ;;
        "southeastasia") echo "Southeast Asia" ;;
        "australiaeast") echo "Australia East" ;;
        "australiacentral") echo "Australia Central" ;;
        "australiacentral2") echo "Australia Central 2" ;;
        "australiasoutheast") echo "Australia Southeast" ;;
        "japaneast") echo "Japan East" ;;
        "japanwest") echo "Japan West" ;;
        "koreacentral") echo "Korea Central" ;;
        "koreasouth") echo "Korea South" ;;
        "indiawest") echo "India West" ;;
        "indiacentral") echo "India Central" ;;
        "indiasouth") echo "India South" ;;
        "indiaeast") echo "India East" ;;
        "indianorth") echo "India North" ;;
        "chinanorth") echo "China North" ;;
        "chinanorth2") echo "China North 2" ;;
        "chinanorth3") echo "China North 3" ;;
        "chinaeast") echo "China East" ;;
        "chinaeast2") echo "China East 2" ;;
        "chinaeast3") echo "China East 3" ;;
        "chinanorthcentral") echo "China North Central" ;;
        "chinawestcentral") echo "China West Central" ;;
        "chinawest") echo "China West" ;;
        "chinawest2") echo "China West 2" ;;
        "chinawest3") echo "China West 3" ;;
        
        # Middle East & Africa
        "uaenorth") echo "UAE North" ;;
        "uaecentral") echo "UAE Central" ;;
        "southafricanorth") echo "South Africa North" ;;
        "southafricawest") echo "South Africa West" ;;
        "israelcentral") echo "Israel Central" ;;
        "qatarcentral") echo "Qatar Central" ;;
        
        # South America
        "brazilsouth") echo "Brazil South" ;;
        "brazilsoutheast") echo "Brazil Southeast" ;;
        "chilesouthcentral") echo "Chile South Central" ;;
        "argentinasouth") echo "Argentina South" ;;
        "peruwest") echo "Peru West" ;;
        "colombiasouth") echo "Colombia South" ;;
        "mexicocentral") echo "Mexico Central" ;;
        "mexicowest") echo "Mexico West" ;;
        
        *) echo "" ;;
    esac
}

# Function to list all regions
list_all_regions() {
    echo "Available Azure Regions:"
    echo "======================"
    # List all regions in order
    local regions=(
        "eastus" "eastus2" "westus" "westus2" "westus3" "centralus" "northcentralus" "southcentralus" "westcentralus" "canadacentral" "canadaeast"
        "northeurope" "westeurope" "uksouth" "ukwest" "francecentral" "francesouth" "germanynorth" "germanywestcentral" "switzerlandnorth" "switzerlandwest" "norwayeast" "norwaywest" "swedencentral" "swedensouth" "polandcentral" "italynorth" "austriaeast" "belgiumcentral" "czechrepubliccentral" "denmarkeast" "finlandcentral" "greecenorth" "hungarycentral" "irelandnorth" "latvialcentral" "lithuaniasouth" "luxembourgnorth" "maltaintermediate" "netherlandsnorth" "portugalcentral" "sloveniawest" "slovakiacentral" "spaincentral"
        "eastasia" "southeastasia" "australiaeast" "australiacentral" "australiacentral2" "australiasoutheast" "japaneast" "japanwest" "koreacentral" "koreasouth" "indiawest" "indiacentral" "indiasouth" "indiaeast" "indianorth" "chinanorth" "chinanorth2" "chinanorth3" "chinaeast" "chinaeast2" "chinaeast3" "chinanorthcentral" "chinawestcentral" "chinawest" "chinawest2" "chinawest3"
        "uaenorth" "uaecentral" "southafricanorth" "southafricawest" "israelcentral" "qatarcentral"
        "brazilsouth" "brazilsoutheast" "chilesouthcentral" "argentinasouth" "peruwest" "colombiasouth" "mexicocentral" "mexicowest"
    )
    
    for region in "${regions[@]}"; do
        local region_name=$(get_region_name "$region")
        echo "$region - $region_name"
    done
}

# Function to get regions by geography
get_regions_by_geography() {
    local geography=$1
    case $geography in
        "north-america"|"na")
            echo "eastus,eastus2,westus,westus2,westus3,centralus,northcentralus,southcentralus,westcentralus,canadacentral,canadaeast"
            ;;
        "europe"|"eu")
            echo "northeurope,westeurope,uksouth,ukwest,francecentral,francesouth,germanynorth,germanywestcentral,switzerlandnorth,switzerlandwest,norwayeast,norwaywest,swedencentral,swedensouth,polandcentral,italynorth,austriaeast,belgiumcentral,czechrepubliccentral,denmarkeast,finlandcentral,greecenorth,hungarycentral,irelandnorth,latvialcentral,lithuaniasouth,luxembourgnorth,maltaintermediate,netherlandsnorth,portugalcentral,sloveniawest,slovakiacentral,spaincentral"
            ;;
        "asia-pacific"|"ap")
            echo "eastasia,southeastasia,australiaeast,australiacentral,australiacentral2,australiasoutheast,japaneast,japanwest,koreacentral,koreasouth,indiawest,indiacentral,indiasouth,indiaeast,indianorth,chinanorth,chinanorth2,chinanorth3,chinaeast,chinaeast2,chinaeast3,chinanorthcentral,chinawestcentral,chinawest,chinawest2,chinawest3"
            ;;
        "middle-east-africa"|"mea")
            echo "uaenorth,uaecentral,southafricanorth,southafricawest,israelcentral,qatarcentral"
            ;;
        "south-america"|"sa")
            echo "brazilsouth,brazilsoutheast,chilesouthcentral,argentinasouth,peruwest,colombiasouth,mexicocentral,mexicowest"
            ;;
        *)
            echo "Unknown geography: $geography"
            echo "Available geographies: north-america, europe, asia-pacific, middle-east-africa, south-america"
            return 1
            ;;
    esac
}

# Function to validate region
validate_region() {
    local region=$1
    local region_name=$(get_region_name "$region")
    if [[ -n "$region_name" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get region display name
get_region_display_name() {
    local region=$1
    local region_name=$(get_region_name "$region")
    echo "${region_name:-$region}"
}

# Function to generate GitHub Actions matrix
generate_matrix() {
    local regions=$1
    local regions_array=($(echo $regions | tr ',' ' '))
    local matrix="["
    
    for region in "${regions_array[@]}"; do
        region=$(echo $region | xargs) # trim whitespace
        if validate_region "$region"; then
            matrix+="\"$region\","
        else
            echo "Warning: Invalid region '$region' skipped" >&2
        fi
    done
    
    # Remove trailing comma and close bracket
    matrix="${matrix%,}]"
    echo "$matrix"
}

# Function to run sequential tests
run_sequential_tests() {
    local regions=$1
    local regions_array=($(echo $regions | tr ',' ' '))
    
    echo "Starting sequential testing for ${#regions_array[@]} regions..."
    echo "Regions: ${regions_array[*]}"
    echo ""
    
    for region in "${regions_array[@]}"; do
        region=$(echo $region | xargs) # trim whitespace
        if validate_region "$region"; then
            echo "Testing region: $region (${AZURE_REGIONS[$region]})"
            # Here you would trigger the GitHub Action for this specific region
            echo "  -> Would trigger test for $region"
        else
            echo "Skipping invalid region: $region"
        fi
        echo ""
    done
}

# Main script logic
case "${1:-help}" in
    "list")
        list_all_regions
        ;;
    "geography")
        if [ -z "$2" ]; then
            echo "Usage: $0 geography <geography-name>"
            echo "Available geographies: north-america, europe, asia-pacific, middle-east-africa, south-america"
            exit 1
        fi
        get_regions_by_geography "$2"
        ;;
    "validate")
        if [ -z "$2" ]; then
            echo "Usage: $0 validate <region-name>"
            exit 1
        fi
        if validate_region "$2"; then
            echo "✓ Region '$2' is valid (${AZURE_REGIONS[$2]})"
        else
            echo "✗ Region '$2' is invalid"
            exit 1
        fi
        ;;
    "matrix")
        if [ -z "$2" ]; then
            echo "Usage: $0 matrix <comma-separated-regions>"
            exit 1
        fi
        generate_matrix "$2"
        ;;
    "sequential")
        if [ -z "$2" ]; then
            echo "Usage: $0 sequential <comma-separated-regions>"
            exit 1
        fi
        run_sequential_tests "$2"
        ;;
    "help"|*)
        echo "Azure Regions Management Script"
        echo "==============================="
        echo ""
        echo "Usage: $0 <command> [arguments]"
        echo ""
        echo "Commands:"
        echo "  list                           - List all available regions"
        echo "  geography <name>               - Get regions by geography"
        echo "  validate <region>              - Validate a region name"
        echo "  matrix <regions>               - Generate GitHub Actions matrix"
        echo "  sequential <regions>           - Run sequential tests"
        echo "  help                           - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 geography europe"
        echo "  $0 validate eastus"
        echo "  $0 matrix \"eastus,westus,centralus\""
        echo "  $0 sequential \"eastus,westus,centralus\""
        echo ""
        echo "Geographies:"
        echo "  north-america, europe, asia-pacific, middle-east-africa, south-america"
        ;;
esac