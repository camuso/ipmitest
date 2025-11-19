# IPMI Test Harness - Example Output

## Example 1: Running All Tests

```bash
$ ./ipmi-test-harness -H 192.168.1.100 -U admin -P password

[INFO] Test session started: session-20251119-101523-12345
[INFO] Log file: /var/log/ipmi-tests/session-20251119-101523-12345.log
[INFO] BMC Host: 192.168.1.100
[INFO] BMC User: admin
[INFO] Test Suite: all

==========================================
Sensor Monitoring Tests
==========================================
[PASS] sensor_list: Retrieved 45 sensors
[PASS] sensor_get: Successfully read sensor: CPU Temp
[PASS] sensor_get: Successfully read sensor: System Temp
[PASS] sensor_get: Successfully read sensor: Fan1
[SKIP] sensor_thresholds: Sensor may not support thresholds
[PASS] sensor_thresholds: Successfully retrieved thresholds
[PASS] sensor_consistency: Retrieved 3 consistent readings

Sensor Module Summary:
  Tests: 7
  Passed: 6
  Failed: 0
  Skipped: 1

==========================================
Chassis Power Control Tests
==========================================
[PASS] chassis_status: Successfully retrieved chassis status
[PASS] power_status: Power state: on
[SKIP] power_cycle: Skipped in dry-run mode (destructive operation)
[SKIP] power_reset: Skipped in dry-run mode (destructive operation)
[SKIP] power_soft: Skipped in dry-run mode (destructive operation)
[INFO] state_restore: Power state already at initial state

Chassis Module Summary:
  Tests: 6
  Passed: 2
  Failed: 0
  Skipped: 4

==========================================
System Event Log Tests
==========================================
[PASS] sel_info: Successfully retrieved SEL information
[PASS] sel_list: Retrieved 127 SEL entries
[PASS] sel_get: Successfully retrieved SEL entry
[PASS] sel_time: Successfully retrieved SEL time
[PASS] sel_backup: SEL backed up successfully
[PASS] sel_clear: SEL successfully cleared
[INFO] sel_restore: SEL backup available at: /var/log/ipmi-tests/sel-backup-session-20251119-101523-12345.txt

SEL Module Summary:
  Tests: 6
  Passed: 6
  Failed: 0
  Skipped: 0

==========================================
Authentication and Security Tests
==========================================
[PASS] auth_status: Authentication successful
[PASS] user_list: Retrieved 5 users
[PASS] user_info: Successfully retrieved user information
[PASS] channel_auth: Retrieved channel authentication capabilities
[PASS] session_info: Successfully retrieved session information
[PASS] invalid_auth: Invalid authentication correctly rejected

Auth Module Summary:
  Tests: 6
  Passed: 6
  Failed: 0
  Skipped: 0

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

## Example 2: Verbose Mode

```bash
$ ./ipmi-test-harness -H 192.168.1.100 -U admin -P password -v -m sensors

[INFO] Test session started: session-20251119-101530-12346
[INFO] Log file: /var/log/ipmi-tests/session-20251119-101530-12346.log
[INFO] BMC Host: 192.168.1.100
[INFO] BMC User: admin
[INFO] Test Suite: sensors
[INFO] Verbose: 1
[INFO] Dry Run: 0
[INFO] Fail Fast: 0

==========================================
Sensor Monitoring Tests
==========================================
[TEST] Testing sensor list retrieval
[DEBUG] Command: ipmitool sensor list
[DEBUG] Output: CPU Temp         | 45 degrees C      | ok
[PASS] sensor_list: Retrieved 45 sensors
[TEST] Testing sensor read: CPU Temp
[DEBUG] Command: ipmitool sensor get "CPU Temp"
[DEBUG] Output: Sensor Reading          : 45 (+/- 0) degrees C
[PASS] sensor_get: Successfully read sensor: CPU Temp
...
```

## Example 3: Dry-Run Mode

```bash
$ ./ipmi-test-harness -H 192.168.1.100 -U admin -P password -d -v -m chassis

[INFO] Test session started: session-20251119-101540-12347
[INFO] Dry Run: 1

==========================================
Chassis Power Control Tests
==========================================
[TEST] Testing chassis status retrieval
[DRY-RUN] ipmitool chassis status
[PASS] chassis_status: Successfully retrieved chassis status
[TEST] Testing power status command
[DRY-RUN] ipmitool chassis power status
[PASS] power_status: Power state: on
[SKIP] power_cycle: Skipped in dry-run mode (destructive operation)
[SKIP] power_reset: Skipped in dry-run mode (destructive operation)
[SKIP] power_soft: Skipped in dry-run mode (destructive operation)
...
```

## Example 4: Fail-Fast Mode

```bash
$ ./ipmi-test-harness -H 192.168.1.100 -U admin -P password -f -m sensors

==========================================
Sensor Monitoring Tests
==========================================
[PASS] sensor_list: Retrieved 45 sensors
[FAIL] sensor_get: Command failed: timeout
[ERROR] Module sensors failed
[ERROR] Stopping due to fail-fast mode

==========================================
Test Execution Summary
==========================================
Session ID: session-20251119-101550-12348
Total Modules: 1
Passed: 0
Failed: 1
Skipped: 0
==========================================
```

## Example 5: Log File Contents

```bash
$ cat /var/log/ipmi-tests/session-20251119-101523-12345.log

[2025-11-19 10:15:23] [INFO] [admin] Test session started: session-20251119-101523-12345
[2025-11-19 10:15:23] [INFO] [admin] Log file: /var/log/ipmi-tests/session-20251119-101523-12345.log
[2025-11-19 10:15:23] [INFO] [admin] BMC Host: 192.168.1.100
[2025-11-19 10:15:23] [INFO] [admin] BMC User: admin
[2025-11-19 10:15:23] [TEST] [admin] [sensor_list] [PASS] Retrieved 45 sensors
[2025-11-19 10:15:24] [TEST] [admin] [sensor_get] [PASS] Successfully read sensor: CPU Temp
[2025-11-19 10:15:25] [TEST] [admin] [sensor_get] [PASS] Successfully read sensor: System Temp
[2025-11-19 10:15:26] [TEST] [admin] [sensor_thresholds] [SKIP] Sensor may not support thresholds
[2025-11-19 10:15:27] [INFO] [admin] Module sensors completed successfully
[2025-11-19 10:15:28] [TEST] [admin] [chassis_status] [PASS] Successfully retrieved chassis status
...
```

## Example 6: Error Handling

```bash
$ ./ipmi-test-harness -H invalid-host -U admin -P password

[INFO] Test session started: session-20251119-101600-12349
[ERROR] auth_status: Authentication failed: Unable to connect to invalid-host
[FAIL] auth_status: Authentication failed
[ERROR] Module auth failed

==========================================
Test Execution Summary
==========================================
Session ID: session-20251119-101600-12349
Total Modules: 4
Passed: 0
Failed: 4
Skipped: 0
==========================================
```

## Example 7: Help Output

```bash
$ ./ipmi-test-harness --help

ipmi-test-harness [-h|--help] [OPTIONS]

Comprehensive IPMI test harness for BMC validation. Tests sensor monitoring,
power control, event logging, and authentication across diverse BMC implementations.

Options:
  -h, --help              Show this help message
  -c, --config FILE       Configuration file (default: ipmi-test.conf)
  -H, --host HOST         BMC hostname or IP address
  -U, --user USER         BMC username
  -P, --pass PASS         BMC password
  -m, --module MODULE     Run specific test module (sensors|chassis|sel|auth|all)
  -l, --log-dir DIR       Log directory (default: /var/log/ipmi-tests)
  -v, --verbose           Verbose output
  -d, --dry-run           Dry run mode (show what would be executed)
  -f, --fail-fast         Stop on first test failure
  -s, --suite SUITE       Test suite name (default: all)

Test Modules:
  sensors    - Sensor monitoring and reading tests
  chassis    - Chassis power control tests
  sel        - System Event Log operations
  auth       - Authentication and security tests
  all        - Run all test modules (default)

Examples:
  # Run all tests with default config
  ipmi-test-harness

  # Run specific module with custom host
  ipmi-test-harness -H 192.168.1.100 -U admin -P password -m sensors

  # Verbose dry-run to see what would be tested
  ipmi-test-harness -v -d -m chassis

  # Run with custom config and log directory
  ipmi-test-harness -c /path/to/config.conf -l /tmp/ipmi-logs
```

