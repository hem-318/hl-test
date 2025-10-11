#!/bin/bash
# Script to diagnose and fix SKU JSON issues

set -euo pipefail

REGION="${1:-eastus}"

echo "Downloading SKU data for $REGION..."
az vm list-skus --location "$REGION" --resource-type virtualMachines --all -o json > raw_skus.json

echo "File size: $(wc -c < raw_skus.json) bytes"
echo "Line count: $(wc -l < raw_skus.json) lines"

# Check if it's valid JSON
if jq -e '.' raw_skus.json >/dev/null 2>&1; then
    echo "JSON is valid"
else
    echo "JSON is invalid!"
    exit 1
fi

# Try to find problematic entries
echo "Checking for problematic entries..."
jq -r 'to_entries | .[] | select(.value | type != "object") | .key' raw_skus.json > bad_indices.txt

if [[ -s bad_indices.txt ]]; then
    echo "Found non-object entries at indices:"
    cat bad_indices.txt
else
    echo "All entries are objects"
fi

# Check for entries with string capabilities
echo "Checking for entries with string capabilities..."
jq -r 'to_entries | .[] | select(.value.capabilities | type == "string") | .key' raw_skus.json > bad_caps.txt

if [[ -s bad_caps.txt ]]; then
    echo "Found entries with string capabilities at indices:"
    cat bad_caps.txt
else
    echo "All capabilities are properly formatted"
fi

# Try our query with just the first 100 entries
echo "Testing query on first 100 entries..."
jq -r '.[0:100]' raw_skus.json > test_subset.json

if jq -r 'def cap($n): if type != "object" then empty elif .capabilities == null then empty elif (.capabilities | type) != "array" then empty else (.capabilities | map(select(type == "object" and .name == $n)) | if length > 0 then .[0].value else empty end) end; .[] | select(type == "object" and .resourceType=="virtualMachines") | .name' test_subset.json > test_output.txt 2>test_error.txt; then
    echo "Query successful on subset. Found $(wc -l < test_output.txt) VMs"
else
    echo "Query failed on subset:"
    cat test_error.txt
fi

# Cleanup
rm -f bad_indices.txt bad_caps.txt test_subset.json test_output.txt test_error.txt
