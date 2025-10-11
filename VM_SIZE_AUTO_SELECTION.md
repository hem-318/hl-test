# Azure VM Size Auto-Selection Implementation

## Overview

The Azure latency workflow has been updated to automatically select the best available VM size per region, with intelligent fallback capabilities. This ensures tests can run even when preferred VM sizes are unavailable due to capacity constraints or regional limitations.

## Key Features

### 1. Dynamic VM Size Discovery
- Queries Azure for all available VM SKUs in each region
- Filters for VMs meeting minimum requirements (4 vCPU, 8GB RAM)
- Prioritizes based on:
  - Preferred list (Standard_F4s_v2 as top choice)
  - Accelerated Networking support
  - Premium/SSD storage capability
  - Minimal resource usage (cost optimization)

### 2. Intelligent Ranking System
The workflow uses a sophisticated ranking algorithm:
```
1. First Priority: Preferred VM sizes (if available)
   - Standard_F4s_v2
   - Standard_D4ds_v5
   - Standard_D4s_v5
   - Standard_D4s_v3
   - Standard_F4s
   - Standard_D4as_v5

2. Second Priority: Other matching VMs, sorted by:
   - Accelerated Networking capability (preferred)
   - Premium IO support (preferred)
   - Lowest vCPU count (cost optimization)
   - Lowest memory (cost optimization)
   - Alphabetical by name (consistency)
```

### 3. Accelerated Networking Auto-Detection
- Automatically detects if selected VM size supports Accelerated Networking
- Configures NIC creation accordingly
- No manual intervention required

### 4. Retry Logic with Fallback
- Attempts VM creation with best available size
- On failure (capacity, quota, etc.), automatically tries next candidate
- Supports up to 6 fallback attempts per region
- Gracefully skips regions where no suitable VMs are available

### 5. Enhanced Resource Management
- Creates dedicated networking resources per region (VNet, Subnet, NSG, Public IP)
- Proper cleanup of all resources after test completion
- Better isolation and security

## Error Handling

The workflow handles multiple failure scenarios:
- **SkuNotAvailable**: VM size not offered in region
- **AllocationFailed**: Temporary capacity issues
- **OperationNotAllowed**: Permission or policy restrictions
- **Conflict**: Resource conflicts
- **Insufficient/Overconstrained**: Capacity exhaustion
- **Quota**: Subscription quota limits

## Usage

No changes required to workflow triggers or parameters. The auto-selection happens transparently:

```bash
# Manual trigger (works as before)
gh workflow run latency-test.yml

# With specific regions
gh workflow run latency-test.yml -f test_regions="eastus,westus2,northeurope"

# Sequential mode
gh workflow run latency-test.yml -f sequential_mode=true
```

## Benefits

1. **Higher Success Rate**: Tests complete even when preferred VM sizes are unavailable
2. **Cost Optimization**: Automatically selects the most cost-effective VM meeting requirements
3. **Regional Coverage**: Can test more regions without manual SKU research
4. **Future Proof**: Adapts to new VM sizes as Azure adds them
5. **Performance Consistency**: Prioritizes VMs with Accelerated Networking for better test accuracy

## Monitoring

The workflow now reports which VM size was actually used in each region:
- Check the workflow logs for real-time selection details
- Final results include VM size information
- Failed regions clearly indicate "No suitable VM size available"

## Troubleshooting

If a region fails to provision:
1. Check workflow logs for the specific error
2. Look for the VM size attempts and failure reasons
3. Common issues:
   - Subscription quota limits (request increase)
   - Regional capacity (try again later)
   - Policy restrictions (check Azure policies)

## Technical Implementation

The implementation uses Azure CLI's `az vm list-skus` command with jq for sophisticated JSON processing:
- Extracts VM capabilities from Azure's capability model
- Builds a ranked candidate list
- Handles edge cases and malformed data gracefully
- Preserves all existing workflow functionality

## Future Enhancements

Potential improvements for consideration:
1. Cache SKU information to reduce API calls
2. Add VM family preferences (e.g., prefer AMD vs Intel)
3. Cost-based ranking using pricing API
4. Historical success rate tracking per size/region
5. Automatic quota increase requests
