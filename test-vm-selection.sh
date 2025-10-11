#!/bin/bash
# Robust VM size selection test
# Usage: ./test-vm-robust.sh <region>

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
az vm list-skus --location "$REGION" --resource-type virtualMachines --all -o json > _skus.json

# First, let's filter to only valid VM entries
echo "Filtering valid VM entries..."
jq -r '[
  .[] | 
  select(
    type == "object" and 
    .resourceType == "virtualMachines" and 
    .name != null and 
    (.name | type) == "string" and
    .capabilities != null and
    (.capabilities | type) == "array"
  )
]' _skus.json > _valid_skus.json

echo "Found $(jq 'length' _valid_skus.json) valid VM SKUs"

# Now process the valid entries
jq -r --argjson pref '[
  "Standard_F4s_v2","Standard_D4ds_v5","Standard_D4s_v5",
  "Standard_D4s_v3","Standard_F4s","Standard_D4as_v5"
]' '
  def getcap($caps; $name):
    ($caps | map(select(.name == $name)) | if length > 0 then .[0].value else null end);
    
  [.[] | 
   select(.restrictions | length == 0) |
   . as $vm |
   {
     name: .name,
     vcpus: (getcap(.capabilities; "vCPUs") | tonumber? // 0),
     mem: (getcap(.capabilities; "MemoryGB") | tonumber? // 0),
     premium: (getcap(.capabilities; "PremiumIO") == "True"),
     an: (getcap(.capabilities; "AcceleratedNetworkingEnabled") == "True")
   } | 
   select(.vcpus >= 4 and .mem >= 8)
  ] as $all |
  # Get preferred VMs first
  ($all | map(select(.name as $n | $pref | index($n)))) as $preferred |
  # Get non-preferred VMs
  ($all | map(select(.name as $n | $pref | index($n) | not))) as $others |
  # Sort preferred by original preference order
  ($preferred | sort_by(.name as $n | $pref | index($n))) as $sorted_pref |
  # Sort others by capabilities
  ($others | sort_by((if .an then 0 else 1 end), (if .premium then 0 else 1 end), .vcpus, .mem, .name)) as $sorted_others |
  # Combine
  ($sorted_pref + $sorted_others)
' _valid_skus.json > candidates.json

# Clean up temp files
rm -f _skus.json _valid_skus.json

if [[ ! -s candidates.json ]] || [[ $(jq 'length' candidates.json) -eq 0 ]]; then
    echo "No matching VM sizes found in $REGION"
    exit 1
fi

echo -e "\nTop 10 VM candidates for $REGION:"
echo "=================================="
printf "%-5s %-30s %-6s %-8s %-8s %-8s\n" "Rank" "VM Size" "vCPUs" "RAM(GB)" "Premium" "AccelNet"
echo "--------------------------------------------------------------------"

jq -r '.[0:10] | to_entries | .[] | 
  [(.key + 1), .value.name, .value.vcpus, .value.mem, .value.premium, .value.an] | @tsv' candidates.json | \
while IFS=$'\t' read -r rank name vcpus mem premium an; do
    printf "%-5s %-30s %-6s %-8s %-8s %-8s\n" "$rank" "$name" "$vcpus" "$mem" "$premium" "$an"
done

echo -e "\nSelected VM size: $(jq -r '.[0].name // "None"' candidates.json)"
echo "Accelerated Networking: $(jq -r '.[0].an // false' candidates.json)"
echo -e "\nTotal matching VMs found: $(jq 'length' candidates.json)"

# Show preferred sizes that are available
echo -e "\nPreferred sizes available in $REGION:"
jq -r --argjson pref '[
  "Standard_F4s_v2","Standard_D4ds_v5","Standard_D4s_v5",
  "Standard_D4s_v3","Standard_F4s","Standard_D4as_v5"
]' '
  map(select(.name as $n | $pref | index($n))) | 
  map(.name) | .[]
' candidates.json 2>/dev/null || echo "None of the preferred sizes are available"

# Cleanup
rm -f candidates.json
