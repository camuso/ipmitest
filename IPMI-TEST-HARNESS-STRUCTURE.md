# IPMI Test Harness - Structure and Architecture

## File Structure

```
/home/tcamuso/bin/
├── ipmi-test-harness              # Main test harness script
├── ipmi-test.conf.example         # Example configuration file
├── ipmi-test-example.sh           # Example execution script
├── IPMI-TEST-HARNESS-README.md    # Comprehensive documentation
├── IPMI-TEST-HARNESS-QUICKSTART.md # Quick start guide
├── IPMI-TEST-HARNESS-STRUCTURE.md # This file
└── ipmi-test-modules/             # Test module directory
    ├── ipmi-test-sensors.sh       # Sensor monitoring tests
    ├── ipmi-test-chassis.sh       # Chassis power control tests
    ├── ipmi-test-sel.sh           # System Event Log tests
    └── ipmi-test-auth.sh          # Authentication tests
```

## Component Descriptions

### Main Harness (`ipmi-test-harness`)

**Responsibilities:**
- Command-line argument parsing
- Configuration file loading
- Test module orchestration
- Logging infrastructure setup
- Test result aggregation and reporting

**Key Functions:**
- `main()`: Entry point, argument parsing, orchestration
- `load_config()`: Load configuration from file
- `validate_requirements()`: Check tools and modules
- `setup_logging()`: Initialize logging infrastructure
- `run_test_module()`: Execute individual test modules
- `print_summary()`: Display test execution summary
- `log_message()`: Centralized logging with attribution

### Test Modules

Each module follows a consistent structure:

1. **Color Definitions**: Standard color variables
2. **Module Variables**: Test counters (test_count, pass_count, etc.)
3. **Helper Functions**:
   - `log_test()`: Standardized test result logging
   - `run_ipmi_cmd()`: IPMI command execution wrapper
4. **Test Functions**: Individual test cases (`test_*`)
5. **Main Function**: `run_module_tests()` - exported for harness

#### Sensors Module (`ipmi-test-sensors.sh`)

**Tests:**
- Sensor list retrieval
- Individual sensor reading
- Sensor threshold reading
- Reading consistency validation

**Idempotency:** Read-only operations, no state changes

#### Chassis Module (`ipmi-test-chassis.sh`)

**Tests:**
- Chassis status retrieval
- Power status commands
- Power cycle (with state restoration)
- Power reset
- Soft power off

**Idempotency:** 
- Saves initial power state
- Restores state after tests
- Skips destructive operations in dry-run mode

#### SEL Module (`ipmi-test-sel.sh`)

**Tests:**
- SEL information retrieval
- SEL entry listing
- Individual entry retrieval
- SEL clearing (with backup)
- SEL time operations

**Snapshot Safety:**
- Backs up SEL before clearing
- Documents backup location for audit

#### Auth Module (`ipmi-test-auth.sh`)

**Tests:**
- Authentication status validation
- User list retrieval
- User information retrieval
- Channel authentication capabilities
- Session information
- Invalid authentication rejection

**Idempotency:** Read-only operations, no state changes

## Data Flow

```
User Input (CLI/Config)
    ↓
Main Harness
    ↓
Configuration Loading
    ↓
Module Selection
    ↓
For each module:
    Source module file
    Export environment variables
    Call run_module_tests()
        ↓
    Individual test functions
        ↓
    log_test() → Log file + Console
    ↓
Aggregate Results
    ↓
Print Summary
```

## Logging Architecture

### Log File Location
`/var/log/ipmi-tests/session-YYYYMMDD-HHMMSS-PID.log`

### Log Format
```
[timestamp] [level] [user] [test_name] [result] message
```

### Log Levels
- `INFO`: General information
- `WARN`: Warning messages  
- `ERROR`: Error conditions
- `DEBUG`: Debug information (verbose mode)
- `TEST`: Test execution results

### Example Log Entry
```
[2025-11-19 10:15:23] [TEST] [admin] [sensor_list] [PASS] Retrieved 45 sensors
```

## Extension Points

### Adding a New Test Module

1. **Create Module File**: `ipmi-test-modules/ipmi-test-<name>.sh`

2. **Follow Template**:
   ```bash
   #!/bin/bash
   # Color definitions
   # Module variables
   # log_test() function
   # run_ipmi_cmd() function
   # Test functions
   # run_module_tests() function
   # export -f run_module_tests
   ```

3. **Update Main Harness**: Add module name to `required_modules` array

4. **Make Executable**: `chmod +x ipmi-test-modules/ipmi-test-<name>.sh`

### Adding Tests to Existing Module

1. Create test function: `test_<feature>()`
2. Call from `run_module_tests()`
3. Use `log_test()` for results
4. Ensure idempotency

## Design Principles

1. **Modularity**: Each test category in separate module
2. **Idempotency**: Tests can be run multiple times safely
3. **Snapshot Safety**: State preserved/restored where possible
4. **Audit Trail**: All operations logged with attribution
5. **Extensibility**: Easy to add new tests/modules
6. **Configurability**: Support different hardware via config
7. **Error Handling**: Graceful failure with clear messages

## Environment Variables

Modules receive these via `export`:
- `BMC_HOST`: BMC hostname/IP
- `BMC_USER`: BMC username
- `BMC_PASS`: BMC password
- `VERBOSE`: Verbosity level
- `DRY_RUN`: Dry-run flag
- `LOG_FILE`: Log file path
- `SESSION_ID`: Test session identifier

## Return Codes

- `0`: All tests passed
- `1`: One or more tests failed
- `2`: No tests executed
- `130`: Interrupted by user (Ctrl-C)

## Best Practices for Module Development

1. **Always use `log_test()`** for test results
2. **Check `DRY_RUN`** before destructive operations
3. **Save and restore state** when modifying system
4. **Handle errors gracefully** with clear messages
5. **Document test purpose** in function comments
6. **Use consistent naming** (`test_<feature>`)
7. **Return appropriate exit codes** from `run_module_tests()`

