# IPMI Test Harness - Quick Start Guide

## Quick Setup

1. **Install ipmitool**:
   ```bash
   sudo dnf install ipmitool
   ```

2. **Create configuration file**:
   ```bash
   cp ipmi-test.conf.example ipmi-test.conf
   vi ipmi-test.conf  # Edit with your BMC details
   ```

3. **Run tests**:
   ```bash
   ./ipmi-test-harness
   ```

## Common Usage Examples

### Run All Tests
```bash
./ipmi-test-harness
```

### Run Specific Module
```bash
./ipmi-test-harness -m sensors
./ipmi-test-harness -m chassis
./ipmi-test-harness -m sel
./ipmi-test-harness -m auth
```

### Override Config with Command-Line
```bash
./ipmi-test-harness -H 192.168.1.100 -U admin -P password
```

### Verbose Output
```bash
./ipmi-test-harness -v        # Normal verbose
./ipmi-test-harness -v -v     # Debug verbose
```

### Dry-Run Mode (Preview Only)
```bash
./ipmi-test-harness -d -v
```

### Fail-Fast Mode
```bash
./ipmi-test-harness -f -m sensors
```

## Test Output Format

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

## Log Files

Logs are stored in `/var/log/ipmi-tests/` with format:
- Filename: `session-YYYYMMDD-HHMMSS-PID.log`
- Format: `[timestamp] [level] [user] [test] [result] message`

## Adding New Tests

1. Create module file: `ipmi-test-modules/ipmi-test-<name>.sh`
2. Follow template from existing modules
3. Export `run_module_tests` function
4. Use `log_test()` for all test results
5. Make executable: `chmod +x ipmi-test-modules/ipmi-test-<name>.sh`

## Troubleshooting

- **"BMC host not specified"**: Set in config file or use `-H`
- **"Authentication failed"**: Check credentials
- **"ipmitool: command not found"**: Install with `sudo dnf install ipmitool`
- **"Test modules directory not found"**: Ensure `ipmi-test-modules/` exists

For detailed information, see `IPMI-TEST-HARNESS-README.md`.

