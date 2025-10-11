# Azure Multi-Region Latency Testing System

A comprehensive system for testing Hyperliquid trading latency across all Azure regions, designed to find the optimal deployment location for high-frequency trading operations.

## 🚀 Features

- **Sequential Testing**: Test one region at a time to avoid resource conflicts
- **Comprehensive Coverage**: Tests all available Azure regions automatically
- **Detailed Metrics**: Measures data fetch, calculation, and order placement latency
- **Automatic Cleanup**: VMs are automatically deleted after testing
- **Results Aggregation**: Comprehensive analysis and reporting
- **Multiple Export Formats**: Markdown, CSV, and JSON results
- **Region Management**: Easy region selection and validation

## 📁 Project Structure

```
hl-test/
├── .github/workflows/
│   └── latency-test.yml          # GitHub Actions workflow
├── hyperliquid.js               # Core trading and latency testing
├── azure-regions.sh             # Region management utilities
├── aggregate-results.sh          # Results analysis and reporting
├── setup-github-secrets-v2.sh   # Secrets configuration
├── package.json                 # Node.js dependencies
└── test-results/                # Generated test results
    ├── LATEST_RESULTS.md        # Latest aggregated results
    └── LATENCY_RESULTS_*.md     # Timestamped results
```

## 🛠️ Setup

### 1. Prerequisites

- GitHub repository with Actions enabled
- Azure subscription with Contributor access
- GitHub CLI (`gh`) installed and authenticated
- Node.js 20+ (for local testing)

### 2. Configure Secrets

Run the setup script to configure all required secrets:

```bash
./setup-github-secrets-v2.sh
```

This will prompt you for:
- **Azure Service Principal credentials** (Client ID, Tenant ID, Subscription ID, Client Secret)
- **Redis URL** (for market data caching)
- **Private Key** (for Hyperliquid trading authentication)
- **GitHub PAT** (optional, for private repositories)

### 3. Verify Setup

Check that all secrets are configured:

```bash
gh secret list --repo <your-repo>
```

## 🎯 Usage

### Manual Testing

1. Go to your GitHub repository's Actions tab
2. Select "Azure Multi-Region Latency Test"
3. Click "Run workflow"
4. Configure options:
   - **Sequential mode**: `true` (recommended for one region at a time)
   - **Test regions**: Leave empty to test all regions, or specify comma-separated list

### Scheduled Testing

The workflow automatically runs every Monday at 2 AM UTC, testing all available Azure regions.

### Region Management

Use the region management script for advanced control:

```bash
# List all available regions
./azure-regions.sh list

# Get regions by geography
./azure-regions.sh geography europe
./azure-regions.sh geography north-america

# Validate a specific region
./azure-regions.sh validate eastus

# Generate GitHub Actions matrix
./azure-regions.sh matrix "eastus,westus,centralus"

# Run sequential tests for specific regions
./azure-regions.sh sequential "eastus,westus,centralus"
```

### Results Analysis

After testing completes, analyze results locally:

```bash
# Generate comprehensive reports
./aggregate-results.sh
```

This creates:
- `LATENCY_RESULTS_YYYYMMDD_HHMMSS.md` - Detailed analysis report
- `LATEST_RESULTS.md` - Latest results summary
- `latency_results_YYYYMMDD_HHMMSS.csv` - CSV export for further analysis

## 📊 Understanding Results

### Key Metrics

- **Average Latency**: Total execution time per order
- **Data Fetch**: Time to retrieve market data from Redis
- **Calculation**: Time to calculate hedge amounts
- **Params Calculation**: Time to compute order parameters
- **Order Placement**: Time to place orders on Hyperliquid

### Performance Categories

- **Excellent**: < 100ms average latency
- **Good**: 100-300ms average latency
- **Acceptable**: 300-500ms average latency
- **Poor**: > 500ms average latency

### Recommendations

The system automatically provides recommendations based on results:
1. **Primary**: Fastest region for production deployment
2. **Secondary**: Backup regions for redundancy
3. **Avoid**: Regions with high latency or failures

## 🔧 Configuration

### Workflow Parameters

Edit `.github/workflows/latency-test.yml` to customize:

```yaml
env:
  RESOURCE_GROUP: latency-test-rg    # Azure resource group
  VM_SIZE: Standard_F4s_v2           # VM size for testing
  VM_IMAGE: Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest
```

### Test Configuration

Modify `hyperliquid.js` to adjust test parameters:

```javascript
const ordersToExecute = [
  { coin: "SOL", amount: 15 },  // Test amount in USD
  { coin: "ETH", amount: 15 },
];
```

## 🚨 Troubleshooting

### Common Issues

1. **VM Size Not Available**
   - Some regions don't support the specified VM size
   - The workflow automatically skips unavailable regions

2. **All Regions Failed**
   - Check Azure service status
   - Verify secrets are correctly configured
   - Ensure Redis and Hyperliquid APIs are accessible

3. **High Latency Across All Regions**
   - Check network connectivity
   - Verify Redis connection performance
   - Consider testing during different time periods

### Debugging

1. **Check GitHub Actions logs** for detailed error messages
2. **Verify secrets** using `gh secret list --repo <your-repo>`
3. **Test locally** by running `node hyperliquid.js` with proper environment variables

## 📈 Monitoring

### Automated Monitoring

- Results are automatically committed to the repository
- Weekly reports are generated and stored in `test-results/`
- Failed regions are automatically retried in subsequent runs

### Manual Monitoring

- Check GitHub Actions for real-time progress
- Review `LATEST_RESULTS.md` for current status
- Use `./aggregate-results.sh` for detailed analysis

## 🔒 Security

- All secrets are stored securely in GitHub Secrets
- VMs are automatically deleted after testing
- Private keys are never logged or stored in plain text
- Redis connections use encrypted URLs

## 📝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the ISC License - see the package.json file for details.

## 🆘 Support

For issues and questions:
1. Check the GitHub Actions logs
2. Review the troubleshooting section
3. Open an issue in the repository
4. Check Azure service status

---

**Note**: This system is designed for testing purposes. Always verify results and consider additional factors like cost, compliance, and availability when choosing production deployment regions.
