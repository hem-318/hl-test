#!/bin/bash

# GitHub Secrets Setup Script for Azure Multi-Region Latency Test Workflow
# This script helps set up required secrets WITHOUT hardcoding them
# Updated for sequential region testing and comprehensive results aggregation

echo "=== GitHub Secrets Setup for Azure Multi-Region Latency Test Workflow ==="
echo ""
echo "This script will help you add the required secrets to your GitHub repository."
echo "The workflow supports:"
echo "  - Sequential testing (one region at a time)"
echo "  - Parallel testing (multiple regions simultaneously)"
echo "  - Comprehensive results aggregation and analysis"
echo ""
echo "Make sure you have the GitHub CLI (gh) installed and authenticated."
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Please run: gh auth login"
    exit 1
fi

# Get repository name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo "Error: Not in a GitHub repository or cannot determine repository."
    exit 1
fi

echo "Setting up secrets for repository: $REPO"
echo ""

# Function to set a secret
set_secret() {
    local secret_name=$1
    local secret_value=$2
    
    echo -n "Setting secret: $secret_name... "
    if echo "$secret_value" | gh secret set "$secret_name" --repo "$REPO" 2>/dev/null; then
        echo "✓"
    else
        echo "✗ (failed)"
        return 1
    fi
}

echo "=== Step 1: Azure Service Principal Credentials ==="
echo ""
echo "If you haven't created a service principal yet, run:"
echo "az ad sp create-for-rbac --name 'github-latency-test-sp' --role='Contributor' --scopes='/subscriptions/{subscription-id}' --sdk-auth"
echo ""
echo "The command above outputs JSON credentials. You'll need those values."
echo ""

read -p "Enter Azure Client ID: " AZURE_CLIENT_ID
read -p "Enter Azure Tenant ID: " AZURE_TENANT_ID
read -p "Enter Azure Subscription ID: " AZURE_SUBSCRIPTION_ID
read -s -p "Enter Azure Client Secret: " AZURE_CLIENT_SECRET
echo ""
echo ""

# Set individual Azure secrets (for compatibility)
echo "Setting individual Azure secrets..."
set_secret "AZURE_CLIENT_ID" "$AZURE_CLIENT_ID"
set_secret "AZURE_TENANT_ID" "$AZURE_TENANT_ID"
set_secret "AZURE_SUBSCRIPTION_ID" "$AZURE_SUBSCRIPTION_ID"
set_secret "AZURE_CLIENT_SECRET" "$AZURE_CLIENT_SECRET"

echo ""
echo "=== Step 2: Application Credentials ==="
echo "Enter your Redis connection URL and Hyperliquid private key."
echo ""

read -p "Enter Redis URL (starting with rediss://): " REDIS_URL
read -p "Enter Private Key (starting with 0x): " PRIVATE_KEY

# Set application secrets
set_secret "REDIS_URL" "$REDIS_URL"
set_secret "PRIVATE_KEY" "$PRIVATE_KEY"

echo ""
echo "=== Step 3: Optional - GitHub PAT ==="
read -p "Do you need a GitHub PAT for accessing private repositories? (y/n): " NEED_PAT

if [ "$NEED_PAT" = "y" ] || [ "$NEED_PAT" = "Y" ]; then
    read -s -p "Enter GitHub Personal Access Token: " GH_PAT
    echo ""
    set_secret "GH_PAT" "$GH_PAT"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "All secrets have been configured for $REPO"
echo ""
echo "You can verify the secrets were set by running:"
echo "gh secret list --repo $REPO"
echo ""
echo "=== Workflow Usage ==="
echo ""
echo "1. Manual Trigger (Recommended for testing):"
echo "   - Go to: https://github.com/$REPO/actions"
echo "   - Select 'Azure Multi-Region Latency Test'"
echo "   - Click 'Run workflow'"
echo "   - Choose options:"
echo "     * Sequential mode: true (one region at a time)"
echo "     * Test regions: leave empty for all regions"
echo ""
echo "2. Scheduled Runs:"
echo "   - Automatically runs every Monday at 2 AM UTC"
echo "   - Tests all available Azure regions"
echo "   - Results are aggregated and committed to repository"
echo ""
echo "3. Region Management:"
echo "   - Use './azure-regions.sh list' to see all regions"
echo "   - Use './azure-regions.sh geography europe' for specific geographies"
echo "   - Use './aggregate-results.sh' to analyze results locally"
echo ""
echo "=== Key Features ==="
echo "✓ Sequential testing (one region at a time)"
echo "✓ Comprehensive results aggregation"
echo "✓ Automatic VM cleanup"
echo "✓ Detailed performance metrics"
echo "✓ CSV and Markdown exports"
echo "✓ Region availability checking"
echo ""
echo "NOTE: The workflow has been updated to use azure/login@v1 with the creds format."
echo "This is compatible with the individual secrets we just set up."
