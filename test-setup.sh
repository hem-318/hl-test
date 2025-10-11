#!/bin/bash

# Local Test Script for Azure Multi-Region Latency Testing System
# This script helps verify the setup works correctly before running on Azure

set -e

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Node.js version
check_node_version() {
    if command_exists node; then
        local version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$version" -ge 20 ]; then
            print_status $GREEN "✓ Node.js version $version (>= 20 required)"
            return 0
        else
            print_status $RED "✗ Node.js version $version (< 20 required)"
            return 1
        fi
    else
        print_status $RED "✗ Node.js not installed"
        return 1
    fi
}

# Function to check npm packages
check_npm_packages() {
    if [ -f "package.json" ]; then
        print_status $BLUE "Checking npm packages..."
        
        if command_exists npm; then
            # Check if node_modules exists
            if [ -d "node_modules" ]; then
                print_status $GREEN "✓ node_modules directory exists"
            else
                print_status $YELLOW "⚠ node_modules not found, running npm install..."
                npm install
            fi
            
            # Check critical packages
            local critical_packages=("hyperliquid" "ioredis" "axios")
            for package in "${critical_packages[@]}"; do
                if npm list "$package" >/dev/null 2>&1; then
                    print_status $GREEN "✓ $package installed"
                else
                    print_status $RED "✗ $package not installed"
                    return 1
                fi
            done
        else
            print_status $RED "✗ npm not installed"
            return 1
        fi
    else
        print_status $RED "✗ package.json not found"
        return 1
    fi
}

# Function to check environment variables
check_environment() {
    print_status $BLUE "Checking environment variables..."
    
    local required_vars=("REDIS_URL" "PRIVATE_KEY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -n "${!var}" ]; then
            print_status $GREEN "✓ $var is set"
        else
            print_status $RED "✗ $var is not set"
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_status $YELLOW "Missing environment variables: ${missing_vars[*]}"
        print_status $YELLOW "Create a .env file with:"
        for var in "${missing_vars[@]}"; do
            echo "  $var=your_value_here"
        done
        return 1
    fi
    
    return 0
}

# Function to test Redis connection
test_redis_connection() {
    if [ -n "$REDIS_URL" ]; then
        print_status $BLUE "Testing Redis connection..."
        
        # Create a simple test script
        cat > test_redis.js << 'EOF'
const Redis = require("ioredis");

async function testRedis() {
    try {
        const redis = new Redis(process.env.REDIS_URL);
        await redis.ping();
        console.log("✓ Redis connection successful");
        redis.disconnect();
        process.exit(0);
    } catch (error) {
        console.log("✗ Redis connection failed:", error.message);
        process.exit(1);
    }
}

testRedis();
EOF
        
        if node test_redis.js; then
            print_status $GREEN "✓ Redis connection test passed"
            rm test_redis.js
            return 0
        else
            print_status $RED "✗ Redis connection test failed"
            rm test_redis.js
            return 1
        fi
    else
        print_status $YELLOW "⚠ REDIS_URL not set, skipping Redis test"
        return 0
    fi
}

# Function to test Hyperliquid connection
test_hyperliquid_connection() {
    if [ -n "$PRIVATE_KEY" ]; then
        print_status $BLUE "Testing Hyperliquid connection..."
        
        # Create a simple test script
        cat > test_hyperliquid.js << 'EOF'
const { Hyperliquid } = require("hyperliquid");

async function testHyperliquid() {
    try {
        const hypeSdk = new Hyperliquid({
            privateKey: process.env.PRIVATE_KEY,
            testnet: true,
            enableWs: true,
        });
        
        await hypeSdk.ws.connect();
        console.log("✓ Hyperliquid connection successful");
        hypeSdk.ws.close();
        process.exit(0);
    } catch (error) {
        console.log("✗ Hyperliquid connection failed:", error.message);
        process.exit(1);
    }
}

testHyperliquid();
EOF
        
        if node test_hyperliquid.js; then
            print_status $GREEN "✓ Hyperliquid connection test passed"
            rm test_hyperliquid.js
            return 0
        else
            print_status $RED "✗ Hyperliquid connection test failed"
            rm test_hyperliquid.js
            return 1
        fi
    else
        print_status $YELLOW "⚠ PRIVATE_KEY not set, skipping Hyperliquid test"
        return 0
    fi
}

# Function to test region management script
test_region_script() {
    if [ -f "azure-regions.sh" ]; then
        print_status $BLUE "Testing region management script..."
        
        if [ -x "azure-regions.sh" ]; then
            print_status $GREEN "✓ azure-regions.sh is executable"
            
            # Test basic functionality
            if ./azure-regions.sh validate eastus >/dev/null 2>&1; then
                print_status $GREEN "✓ Region validation works"
            else
                print_status $RED "✗ Region validation failed"
                return 1
            fi
            
            # Test region listing
            if ./azure-regions.sh list >/dev/null 2>&1; then
                print_status $GREEN "✓ Region listing works"
            else
                print_status $RED "✗ Region listing failed"
                return 1
            fi
        else
            print_status $RED "✗ azure-regions.sh is not executable"
            chmod +x azure-regions.sh
            print_status $YELLOW "✓ Made azure-regions.sh executable"
        fi
    else
        print_status $RED "✗ azure-regions.sh not found"
        return 1
    fi
    
    return 0
}

# Function to test results aggregator script
test_aggregator_script() {
    if [ -f "aggregate-results.sh" ]; then
        print_status $BLUE "Testing results aggregator script..."
        
        if [ -x "aggregate-results.sh" ]; then
            print_status $GREEN "✓ aggregate-results.sh is executable"
        else
            print_status $RED "✗ aggregate-results.sh is not executable"
            chmod +x aggregate-results.sh
            print_status $YELLOW "✓ Made aggregate-results.sh executable"
        fi
    else
        print_status $RED "✗ aggregate-results.sh not found"
        return 1
    fi
    
    return 0
}

# Function to run a quick latency test
run_quick_test() {
    print_status $BLUE "Running quick latency test..."
    
    if [ -f "hyperliquid.js" ]; then
        # Set test environment
        export REGION="local-test"
        
        # Run the test with timeout
        if timeout 60 node hyperliquid.js > quick_test.log 2>&1; then
            print_status $GREEN "✓ Quick latency test completed"
            
            # Check for average latency in output
            if grep -q "Average latency:" quick_test.log; then
                local latency=$(grep "Average latency:" quick_test.log | grep -oP '[\d.]+')
                print_status $GREEN "✓ Average latency: ${latency} ms"
            else
                print_status $YELLOW "⚠ No latency data found in output"
            fi
            
            rm quick_test.log
            return 0
        else
            print_status $RED "✗ Quick latency test failed or timed out"
            if [ -f "quick_test.log" ]; then
                print_status $YELLOW "Last few lines of output:"
                tail -5 quick_test.log
                rm quick_test.log
            fi
            return 1
        fi
    else
        print_status $RED "✗ hyperliquid.js not found"
        return 1
    fi
}

# Main test function
main() {
    print_status $BLUE "Azure Multi-Region Latency Testing System - Local Test"
    print_status $BLUE "======================================================"
    echo ""
    
    local tests_passed=0
    local total_tests=0
    
    # Test 1: Node.js version
    ((total_tests++))
    if check_node_version; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 2: npm packages
    ((total_tests++))
    if check_npm_packages; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 3: Environment variables
    ((total_tests++))
    if check_environment; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 4: Redis connection
    ((total_tests++))
    if test_redis_connection; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 5: Hyperliquid connection
    ((total_tests++))
    if test_hyperliquid_connection; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 6: Region management script
    ((total_tests++))
    if test_region_script; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 7: Results aggregator script
    ((total_tests++))
    if test_aggregator_script; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 8: Quick latency test (optional)
    if [ "$1" = "--full-test" ]; then
        ((total_tests++))
        if run_quick_test; then
            ((tests_passed++))
        fi
        echo ""
    fi
    
    # Summary
    print_status $BLUE "=== TEST SUMMARY ==="
    echo "Tests passed: $tests_passed/$total_tests"
    
    if [ $tests_passed -eq $total_tests ]; then
        print_status $GREEN "🎉 All tests passed! System is ready for deployment."
        echo ""
        print_status $BLUE "Next steps:"
        echo "1. Run './setup-github-secrets-v2.sh' to configure GitHub secrets"
        echo "2. Push your code to GitHub"
        echo "3. Go to Actions tab and run the workflow manually"
        echo "4. Monitor the results in the test-results/ directory"
    else
        print_status $RED "❌ Some tests failed. Please fix the issues before deployment."
        echo ""
        print_status $YELLOW "Common fixes:"
        echo "1. Install missing dependencies: npm install"
        echo "2. Set environment variables in .env file"
        echo "3. Check Redis and Hyperliquid API access"
        echo "4. Make scripts executable: chmod +x *.sh"
    fi
    
    echo ""
    print_status $BLUE "For full testing including latency measurement, run:"
    echo "$0 --full-test"
}

# Run main function
main "$@"
