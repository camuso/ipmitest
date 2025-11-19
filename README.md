# IPMI Test Harness

## Overview

The IPMI Test Harness is a comprehensive, modular testing framework for validating BMC (Baseboard Management Controller) implementations. It provides snapshot-safe, idempotent test routines for sensor monitoring, power control, event logging, and authentication across diverse hardware platforms.

## Features

- **Modular Design**: Separate test modules for different IPMI functions
- **Snapshot-Safe**: Tests can be run repeatedly without side effects
- **Idempotent Operations**: State is preserved and restored where possible
- **Audit-Friendly Logging**: All operations logged with timestamps and user attribution
- **Configurable**: Supports different hardware and simulators via configuration files
- **Extensible**: Easy to add new test modules without breaking existing tests
- **Automated Regression**: Common IPMI commands tested automatically

## Architecture

### Main Components

1. **Main Harness** (`ipmi-test-harness`): Orchestrates test execution
2. **Test Modules** (`ipmi-test-modules/`): Individual test modules
   - `ipmi-test-sensors.sh`: Sensor monitoring tests
   - `ipmi-test-chassis.sh`: Chassis power control tests
   - `ipmi-test-sel.sh`: System Event Log tests
   - `ipmi-test-auth.sh`: Authentication and security tests
3. **Configuration File** (`ipmi-test.conf`): BMC connection and test parameters
4. **Log Directory** (`/var/log/ipmi-tests/`): Test execution logs

### Module Structure

Each test module:
- Exports a `run_module_tests()` function
- Uses standardized logging with `log_test()`
- Implements idempotent operations
- Provides clear pass/fail/skip results

## Installation

1. Ensure `ipmitool` is installed:
   ```bash
   sudo dnf install ipmitool
   ```

2. Copy the example configuration:
   ```bash
   cp ipmi-test.conf.example ipmi-test.conf
   ```

3. Edit `ipmi-test.conf` with your BMC connection details

4. Ensure scripts are executable:
   ```bash
   chmod +x ipmi-test-harness
   chmod +x ipmi-test-modules/*.sh
   ```

## Configuration

### Configuration File Format

```bash
# BMC Connection Parameters
BMC_HOST="192.168.1.100"
BMC_USER="admin"
BMC_PASS="password"

# IPMI Interface
BMC_INTERFACE="lanplus"

# Test Settings
VERBOSE=1
DRY_RUN=0
TEST_SUITE="all"
LOG_DIR="/var/log/ipmi-tests"
```

### Environment Variables

You can override config file settings with environment variables:
- `IPMI_TEST_CONFIG`: Path to config file
- `IPMI_TEST_LOG_DIR`: Log directory path
- `IPMI_TEST_MODULES_DIR`: Test modules directory path

## Usage

### Basic Usage

```bash
# Run all tests with default config
./ipmi-test-harness

# Run specific test module
./ipmi-test-harness -m sensors

# Run with custom BMC connection
./ipmi-test-harness -H 192.168.1.100 -U admin -P password

# Verbose output
./ipmi-test-harness -v

# Dry-run mode (see what would be executed)
./ipmi-test-harness -d -v
```

### Command-Line Options

- `-h, --help`: Show help message
- `-c, --config FILE`: Configuration file path
- `-H, --host HOST`: BMC hostname or IP
- `-U, --user USER`: BMC username
- `-P, --pass PASS`: BMC password
- `-m, --module MODULE`: Run specific module (sensors|chassis|sel|auth|all)
- `-l, --log-dir DIR`: Log directory path
- `-v, --verbose`: Verbose output (can be used multiple times)
- `-d, --dry-run`: Dry-run mode (no actual IPMI commands executed)
- `-f, --fail-fast`: Stop on first test failure
- `-s, --suite SUITE`: Test suite name

### Test Modules

#### Sensors Module (`-m sensors`)

Tests sensor monitoring capabilities:
- Sensor list retrieval
- Individual sensor reading
- Sensor threshold reading
- Reading consistency validation

**Example Output:**
```
==========================================
Sensor Monitoring Tests
==========================================
[PASS] sensor_list: Retrieved 45 sensors
[PASS] sensor_get: Successfully read sensor: CPU Temp
[PASS] sensor_thresholds: Successfully retrieved thresholds
[PASS] sensor_consistency: Retrieved 3 consistent readings
```

#### Chassis Module (`-m chassis`)

Tests chassis power control:
- Chassis status retrieval
- Power status commands
- Power cycle (idempotent with state restoration)
- Power reset
- Soft power off

**Safety Features:**
- Saves initial power state
- Restores state after tests
- Skips destructive operations in dry-run mode

**Example Output:**
```
==========================================
Chassis Power Control Tests
==========================================
[PASS] chassis_status: Successfully retrieved chassis status
[PASS] power_status: Power state: on
[SKIP] power_cycle: Skipped in dry-run mode (destructive operation)
[PASS] state_restore: Power state already at initial state
```

#### SEL Module (`-m sel`)

Tests System Event Log operations:
- SEL information retrieval
- SEL entry listing
- Individual entry retrieval
- SEL clearing (with backup)
- SEL time operations

**Snapshot Safety:**
- Backs up SEL before clearing
- Documents backup location for audit

**Example Output:**
```
==========================================
System Event Log Tests
==========================================
[PASS] sel_info: Successfully retrieved SEL information
[PASS] sel_list: Retrieved 127 SEL entries
[PASS] sel_get: Successfully retrieved SEL entry
[PASS] sel_backup: SEL backed up successfully
[PASS] sel_clear: SEL successfully cleared
```

#### Auth Module (`-m auth`)

Tests authentication and security:
- Authentication status validation
- User list retrieval
- User information retrieval
- Channel authentication capabilities
- Session information
- Invalid authentication rejection

**Example Output:**
```
==========================================
Authentication and Security Tests
==========================================
[PASS] auth_status: Authentication successful
[PASS] user_list: Retrieved 5 users
[PASS] user_info: Successfully retrieved user information
[PASS] channel_auth: Retrieved channel authentication capabilities
[PASS] invalid_auth: Invalid authentication correctly rejected
```

## Logging

### Log File Format

Logs are written to `/var/log/ipmi-tests/session-YYYYMMDD-HHMMSS-PID.log`

Format: `[timestamp] [level] [user] [test_name] [result] message`

Example:
```
[2025-11-19 10:15:23] [INFO] [admin] [session_start] Test session started: session-20251119-101523-12345
[2025-11-19 10:15:24] [TEST] [admin] [sensor_list] [PASS] Retrieved 45 sensors
[2025-11-19 10:15:25] [TEST] [admin] [sensor_get] [FAIL] Command failed: timeout
```

### Log Levels

- `INFO`: General information
- `WARN`: Warning messages
- `ERROR`: Error conditions
- `DEBUG`: Debug information (verbose mode)
- `TEST`: Test execution results

## Extending the Harness

### Adding a New Test Module

1. Create a new module file: `ipmi-test-modules/ipmi-test-<name>.sh`

2. Follow the module template:
   ```bash
   #!/bin/bash
   # Color definitions
   declare OFF="\e[m"
   declare INF="\e[0;93m"
   declare CAU="\e[1;95m"
   declare WRN="\e[0;91m"
   
   # Module variables
   declare -i test_count=0
   declare -i pass_count=0
   declare -i fail_count=0
   declare -i skip_count=0
   
   # log_test function (copy from existing module)
   log_test() { ... }
   
   # run_ipmi_cmd function (copy from existing module)
   run_ipmi_cmd() { ... }
   
   # Your test functions
   test_something() { ... }
   
   # Main function (required)
   run_module_tests() {
       # Your tests here
       return $fail_count
   }
   
   export -f run_module_tests
   ```

3. Update the main harness to include your module in the `enabled_modules` array

4. Make the module executable:
   ```bash
   chmod +x ipmi-test-modules/ipmi-test-<name>.sh
   ```

### Adding Tests to Existing Modules

1. Add your test function following the naming convention: `test_<feature>`
2. Call your test from `run_module_tests()`
3. Use `log_test()` for consistent logging
4. Ensure tests are idempotent (can be run multiple times)

## Best Practices

1. **Idempotency**: Tests should be safe to run multiple times
2. **State Preservation**: Save and restore system state when modifying it
3. **Dry-Run Support**: Destructive operations should check `DRY_RUN` flag
4. **Error Handling**: Always check command return codes
5. **Logging**: Use `log_test()` for all test results
6. **Documentation**: Document test purpose and expected behavior

## Troubleshooting

### Common Issues

1. **"BMC host not specified"**
   - Set `BMC_HOST` in config file or use `-H` option

2. **"Authentication failed"**
   - Verify credentials in config file
   - Check BMC network connectivity

3. **"Test modules directory not found"**
   - Ensure `ipmi-test-modules/` directory exists
   - Check `IPMI_TEST_MODULES_DIR` environment variable

4. **"ipmitool: command not found"**
   - Install ipmitool: `sudo dnf install ipmitool`

### Debug Mode

Use verbose mode for detailed output:
```bash
./ipmi-test-harness -v -v  # Double verbose for debug level
```

## Examples

### Example 1: Quick Sensor Test

```bash
./ipmi-test-harness -H 192.168.1.100 -U admin -P password -m sensors
```

### Example 2: Full Test Suite with Custom Logging

```bash
./ipmi-test-harness \
  -c /path/to/custom.conf \
  -l /tmp/ipmi-test-logs \
  -v \
  -m all
```

### Example 3: Dry-Run to Preview Tests

```bash
./ipmi-test-harness -d -v -m chassis
```

### Example 4: Fail-Fast Mode

```bash
./ipmi-test-harness -f -m sensors
```

## Output Format

### Test Execution Output

```
==========================================
Sensor Monitoring Tests
==========================================
[PASS] sensor_list: Retrieved 45 sensors
[PASS] sensor_get: Successfully read sensor: CPU Temp
[SKIP] sensor_thresholds: Sensor may not support thresholds

Sensor Module Summary:
  Tests: 3
  Passed: 2
  Failed: 0
  Skipped: 1
```

### Final Summary

```
==========================================
Test Execution Summary
==========================================
Session ID: session-20251119-101523-12345
Log File: /var/log/ipmi-tests/session-20251119-101523-12345.log
Total Modules: 4
Passed: 3
Failed: 1
Skipped: 0
==========================================
```

## Contributing

When adding new tests:
1. Follow the coding standards in `BASH_SCRIPT_STANDARDS.md`
2. Ensure tests are idempotent
3. Add appropriate logging
4. Update this documentation
5. Test with both real hardware and simulators

## License

[Add your license information here]

## Support

For issues or questions, please refer to the log files in `/var/log/ipmi-tests/` for detailed error information.

