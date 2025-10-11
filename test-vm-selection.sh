#!/bin/bash
# Test script for VM size selection logic
# Usage: ./test-vm-selection.sh <region>

set -euo pipefail

REGION="${1:-eastus}"

echo "Testing VM size selection for region: $REGION"
echo "============================================"

# Check if logged into Azure
if ! az account show &>/dev/null; then
    echo "Error: Not logged into Azure. Please run 'az login' first."
    exit 1
fi

# Discover available SKUs
echo "Discovering available VM SKUs..."
SKUS_JSON=$(az vm list-skus --location "$REGION" --resource-type virtualMachines --all -o json)

# Helper to extract capability by name
jqcap='
  def cap($n):
    (.capabilities // []) | map(select(.name == $n)) | .[0].value // empty
'

# Build candidate table
echo "$SKUS_JSON" | jq -r --argjson pref '[
  "Standard_F4s_v2","Standard_D4ds_v5","Standard_D4s_v5",
  "Standard_D4s_v3","Standard_F4s","Standard_D4as_v5"
]' '
  '"$jqcap"' 
  [
    .[] 
    | select(.resourceType=="virtualMachines" and (.restrictions|length==0)) 
    | {
        name: .name,
        vcpus: (cap("vCPUs")|tonumber? // 0),
        mem: (cap("MemoryGB")|tonumber? // 0),
        premium: ((cap("PremiumIO")|ascii_downcase)=="true"),
        an: ((cap("AcceleratedNetworkingEnabled")|ascii_downcase)=="true")
      }
    | select(.vcpus >= 4 and .mem >= 8)
  ]
  as $all
  |
  # Preferred list first (if present)
  ( $pref
    | map(.)
    | map( {name:., rank: (index(.) // 9999)} )
    | map(
        . as $p
        | ($all | map(select(.name==$p.name)))[0] // empty
      )
    | map(select(.name != null))
  ) as $preferred
  |
  # Non-preferred matches
  ( $all
    | map(select([.name] | inside($preferred | map(.name)) | not))
    | sort_by( (if .an then 0 else 1 end),
               (if .premium then 0 else 1 end),
               .vcpus, .mem, .name )
  ) as $others
  |
  ($preferred + $others)
' > candidates.json

if [[ ! -s candidates.json ]]; then
    echo "No matching VM sizes found in $REGION"
    exit 1
fi

echo -e "\nTop 10 VM candidates for $REGION:"
echo "=================================="
echo -e "Rank\tName\t\t\tvCPUs\tRAM(GB)\tPremium\tAccelNet"
echo "--------------------------------------------------------------------"

jq -r '.[0:10] | to_entries | .[] | 
  "\(.key + 1)\t\(.value.name)\t\t\(.value.vcpus)\t\(.value.mem)\t\(.value.premium)\t\(.value.an)"' candidates.json | 
  awk -F'\t' '{printf "%-8s%-24s%-8s%-8s%-8s%-8s\n", $1, $2, $3, $4, $5, $6}'

echo -e "\nSelected VM size: $(jq -r '.[0].name' candidates.json)"
echo "Accelerated Networking: $(jq -r '.[0].an' candidates.json)"
echo -e "\nTotal matching VMs found: $(jq 'length' candidates.json)"

# Cleanup
rm -f candidates.json
