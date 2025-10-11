#!/bin/bash
# Debug version of VM size selection test
# Usage: ./test-vm-selection-debug.sh <region>

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

# Validate JSON
if ! jq -e '.' _skus.json >/dev/null 2>&1; then
    echo "Error: Invalid JSON in SKU data"
    exit 1
fi

echo "Downloaded $(jq 'length' _skus.json) SKU entries"

# Build candidate table with error handling
set +e
jq -r --argjson pref '[
  "Standard_F4s_v2","Standard_D4ds_v5","Standard_D4s_v5",
  "Standard_D4s_v3","Standard_F4s","Standard_D4as_v5"
]' '
  def cap($n): 
    if type != "object" then empty
    elif .capabilities == null then empty
    elif (.capabilities | type) != "array" then empty
    else (.capabilities | map(select(type == "object" and .name == $n)) | if length > 0 then .[0].value else empty end)
    end;
  def has_blocking_restriction:
    if type != "object" then false
    else ((.restrictions // []) | map(select(type == "object" and .type == "Location" and .reasonCode != "NotAvailableForSubscription")) | length > 0)
    end;
  [.[] | 
   select(type == "object" and .resourceType=="virtualMachines" and .name != null and (has_blocking_restriction | not)) | 
   {
     name: .name,
     vcpus: (cap("vCPUs") | tonumber? // 0),
     mem: (cap("MemoryGB") | tonumber? // 0),
     premium: ((cap("PremiumIO") | ascii_downcase) == "true"),
     an: ((cap("AcceleratedNetworkingEnabled") | ascii_downcase) == "true")
   } | 
   select(.vcpus >= 4 and .mem >= 8)
  ] as $all |
  ($pref | map(. as $p | ($all | map(select(.name==$p.name)))[0] // empty)) as $preferred |
  ($all | map(select([.name] | inside($preferred | map(.name)) | not)) | 
   sort_by((if .an then 0 else 1 end), (if .premium then 0 else 1 end), .vcpus, .mem, .name)) as $others |
  ($preferred + $others)
' _skus.json > candidates.json 2>jq_error.log
jq_exit_code=$?
set -e

if [[ $jq_exit_code -ne 0 ]]; then
    echo "Error processing SKU data with jq (exit code: $jq_exit_code)"
    if [[ -f jq_error.log ]]; then
        echo "jq error output:"
        cat jq_error.log
    fi
    exit 1
fi

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

# Cleanup
rm -f _skus.json candidates.json jq_error.log
