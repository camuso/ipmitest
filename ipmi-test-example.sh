#!/bin/bash
#
# Example execution script for IPMI Test Harness
#
# This script demonstrates various ways to use the IPMI test harness
#

# Example 1: Run all tests with config file
echo "Example 1: Running all tests with config file"
./ipmi-test-harness -c ipmi-test.conf

# Example 2: Run specific module with command-line credentials
echo ""
echo "Example 2: Running sensors module with command-line credentials"
./ipmi-test-harness -H 192.168.1.100 -U admin -P password -m sensors -v

# Example 3: Dry-run to preview tests
echo ""
echo "Example 3: Dry-run mode to preview tests"
./ipmi-test-harness -H 192.168.1.100 -U admin -P password -d -v -m chassis

# Example 4: Verbose output with custom log directory
echo ""
echo "Example 4: Verbose output with custom log directory"
./ipmi-test-harness -H 192.168.1.100 -U admin -P password -l /tmp/ipmi-logs -v -m all

# Example 5: Fail-fast mode
echo ""
echo "Example 5: Fail-fast mode (stops on first failure)"
./ipmi-test-harness -H 192.168.1.100 -U admin -P password -f -m sensors

