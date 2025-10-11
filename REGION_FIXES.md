# Azure Region and VM Size Fixes

## Issues Fixed

### 1. Region Support for VirtualNetworks
**Problem**: Some regions like `australiacentral2` don't support VirtualNetworks, causing the error:
```
ERROR: (LocationNotAvailableForResourceType) The provided location 'australiacentral2' is not available for resource type 'Microsoft.Network/virtualNetworks'
```

**Solution**: 
- Added filtering to only test regions that support VirtualNetworks
- Using the list of supported regions provided in the error message
- Both automatic region discovery and manual region input are now filtered

### 2. Empty VM Size Selection
**Problem**: VM creation was failing with empty size values:
```
Attempt 2: size=
Unexpected failure creating VM with :
ERROR: expected string or bytes-like object, got 'NoneType'
```

**Solution**:
- Added debug logging to track VM size selection
- Fixed the TSV file generation for fallback candidates
- Added validation to skip empty size values
- Improved error handling in the VM creation loop

### 3. Null VM Size Values
**Problem**: VM creation was failing with null values:
```
Trying sizes in australiacentral: null
Attempt 1: size=null
ERROR: The value null provided for the VM size is not valid
```

**Solution**:
- Updated restriction filtering to allow "NotAvailableForSubscription" VMs (they can still be deployed)
- Added null checks in jq queries using `// empty` operator
- Added explicit null value validation before passing to az vm create
- Enhanced the test script to match the workflow logic

## Implementation Details

### Region Filtering
The workflow now maintains a list of regions that support VirtualNetworks:
- 46 regions are supported as of October 2025
- Regions are filtered before matrix creation
- Invalid regions are silently excluded from testing

### VM Size Selection Improvements
1. Better logging shows selected size and candidates
2. TSV file parsing is more robust
3. Empty values are detected and skipped
4. Fallback candidates are properly read and used

## Testing
To test specific regions:
```bash
# This will automatically filter out unsupported regions
gh workflow run latency-test.yml -f test_regions="westus,australiacentral2,eastus"
# Result: Only westus and eastus will be tested (australiacentral2 filtered out)
```

## Supported Regions
The following regions support both VMs and VirtualNetworks:
- Americas: westus, eastus, northcentralus, southcentralus, centralus, eastus2, westcentralus, westus2, westus3, canadacentral, canadaeast, brazilsouth, mexicocentral, chilecentral
- Europe: northeurope, westeurope, ukwest, uksouth, francecentral, switzerlandnorth, germanywestcentral, norwayeast, swedencentral, polandcentral, italynorth, spaincentral, austriaeast
- Asia Pacific: eastasia, southeastasia, japaneast, japanwest, australiaeast, australiasoutheast, australiacentral, koreacentral, koreasouth, centralindia, southindia, westindia, jioindiawest, indonesiacentral, malaysiawest, newzealandnorth
- Middle East & Africa: southafricanorth, uaenorth, qatarcentral, israelcentral
