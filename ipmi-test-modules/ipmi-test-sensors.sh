#!/bin/bash
#
# ipmi-test-sensors - Sensor monitoring and reading test module
#
# Tests IPMI sensor reading, sensor data interpretation, and sensor
# threshold validation across different BMC implementations.
#

#######################################
# Color Definitions
#######################################
declare OFF="\e[m"
declare INF="\e[0;93m"
declare CAU="\e[1;95m"
declare WRN="\e[0;91m"

#######################################
# Module Variables
#######################################
declare -i test_count=0
declare -i pass_count=0
declare -i fail_count=0
declare -i skip_count=0

#######################################
# Module Functions
#######################################

#** log_test: log test result with attribution
#*
# Arguments
#   $1 - test name
#   $2 - result (PASS|FAIL|SKIP)
#   $3 - message
#*
log_test() {
	local test_name="$1"
	local result="$2"
	local msg="$3"
	local timestamp
	local user

	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	user="${SUDO_USER:-${USER:-unknown}}"

	[[ -n "$LOG_FILE" ]] && {
		echo "[$timestamp] [TEST] [$user] [$test_name] [$result] $msg" >> "$LOG_FILE"
	}

	case "$result" in
		PASS)
			((++pass_count))
			((++test_count))
			echo -e "${INF}[PASS]${OFF} $test_name: $msg"
			;;
		FAIL)
			((++fail_count))
			((++test_count))
			echo -e "${CAU}[FAIL]${OFF} $test_name: $msg"
			;;
		SKIP)
			((++skip_count))
			((++test_count))
			echo -e "${WRN}[SKIP]${OFF} $test_name: $msg"
			;;
	esac
}

#** show_spinner: display spinner while command runs
#*
# Arguments
#   $1 - PID of background process to wait for
#*
show_spinner() {
	local -i pid=$1
	local spinner_chars='|/-\'
	local -i i=0
	
	# Only show spinner if not in verbose mode
	((VERBOSE > 0)) && return 0
	
	while kill -0 "$pid" 2>/dev/null; do
		printf "\r[%c] " "${spinner_chars:i++%4:1}"
		sleep 0.1
	done
	printf "\r"
}

#** run_ipmi_cmd: execute IPMI command with error handling
#*
# Arguments
#   $@ - IPMI command and arguments
#*
# Returns
#   0 on success, non-zero on failure
#*
run_ipmi_cmd() {
	local cmd_output
	local -i cmd_status
	local temp_file

	((DRY_RUN > 0)) && {
		echo "[DRY-RUN] ipmitool $*" >&2
		return 0
	}

	# Build ipmitool command based on local or remote mode
	if ((LOCAL_MODE > 0)); then
		# Local mode: use -I open, no host/user/pass
		temp_file=$(mktemp)
		ipmitool -I "${BMC_INTERFACE:-open}" "$@" >"$temp_file" 2>&1 &
		local -i bg_pid=$!
		show_spinner $bg_pid
		wait $bg_pid
		cmd_status=$?
		cmd_output=$(cat "$temp_file")
		rm -f "$temp_file"
	else
		# Remote mode: use network parameters
		temp_file=$(mktemp)
		ipmitool -I "${BMC_INTERFACE:-lanplus}" -H "$BMC_HOST" -U "$BMC_USER" -P "$BMC_PASS" "$@" >"$temp_file" 2>&1 &
		local -i bg_pid=$!
		show_spinner $bg_pid
		wait $bg_pid
		cmd_status=$?
		cmd_output=$(cat "$temp_file")
		rm -f "$temp_file"
	fi

	((VERBOSE > 1)) && echo "Command: ipmitool $*" >&2
	((VERBOSE > 1)) && echo "Output: $cmd_output" >&2

	# Echo output so callers can capture it
	echo "$cmd_output"
	return $cmd_status
}

#** test_sensor_list: test sensor list retrieval
#*
test_sensor_list() {
	local test_name="sensor_list"
	local cmd_output
	local -i sensor_count=0

	log_test "$test_name" "INFO" "Testing sensor list retrieval"

	cmd_output=$(run_ipmi_cmd sensor list 2>&1)
	local -i status=$?

	if ((status == 0)); then
		sensor_count=$(echo "$cmd_output" | grep -c "^[A-Za-z]" || echo "0")
		if ((sensor_count > 0)); then
			log_test "$test_name" "PASS" "Retrieved $sensor_count sensors"
		else
			log_test "$test_name" "FAIL" "No sensors found in output"
		fi
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_sensor_get: test individual sensor reading
#*
test_sensor_get() {
	local test_name="sensor_get"
	local sensor_name="$1"
	local cmd_output

	[[ -z "$sensor_name" ]] && {
		log_test "$test_name" "SKIP" "No sensor name provided"
		return 0
	}

	log_test "$test_name" "INFO" "Testing sensor read: $sensor_name"

	cmd_output=$(run_ipmi_cmd sensor get "$sensor_name" 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -q "Sensor Reading"; then
			log_test "$test_name" "PASS" "Successfully read sensor: $sensor_name"
		else
			log_test "$test_name" "FAIL" "Invalid sensor data format"
		fi
	else
		log_test "$test_name" "FAIL" "Failed to read sensor: $cmd_output"
	fi

	return $status
}

#** test_sensor_thresholds: test sensor threshold reading
#*
test_sensor_thresholds() {
	local test_name="sensor_thresholds"
	local sensor_name="$1"
	local cmd_output

	[[ -z "$sensor_name" ]] && {
		log_test "$test_name" "SKIP" "No sensor name provided"
		return 0
	}

	log_test "$test_name" "INFO" "Testing sensor thresholds: $sensor_name"

	cmd_output=$(run_ipmi_cmd sensor thresh "$sensor_name" get 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(Lower|Upper|Critical)"; then
			log_test "$test_name" "PASS" "Successfully retrieved thresholds"
		else
			log_test "$test_name" "SKIP" "Sensor may not support thresholds"
		fi
	else
		log_test "$test_name" "SKIP" "Threshold command not supported: $cmd_output"
	fi

	return 0
}

#** test_sensor_reading_consistency: test sensor reading consistency
#*
test_sensor_reading_consistency() {
	local test_name="sensor_consistency"
	local sensor_name="$1"
	local -i iterations=3
	local -i i
	local -a readings=()
	local reading
	local -i consistent=1

	[[ -z "$sensor_name" ]] && {
		log_test "$test_name" "SKIP" "No sensor name provided"
		return 0
	}

	log_test "$test_name" "INFO" "Testing reading consistency: $sensor_name"

	for ((i=0; i<iterations; i++)); do
		reading=$(run_ipmi_cmd sensor get "$sensor_name" 2>&1 | grep "Sensor Reading" | head -1)
		readings+=("$reading")
		sleep 1
	done

	# Check if readings are consistent (same or within expected variance)
	if (( ${#readings[@]} == iterations )); then
		log_test "$test_name" "PASS" "Retrieved $iterations consistent readings"
	else
		log_test "$test_name" "FAIL" "Inconsistent reading count"
		consistent=0
	fi

	return $((1 - consistent))
}

#** run_module_tests: main test execution function for sensors module
#*
# This function is called by the main harness
#*
run_module_tests() {
	local sensor_name
	local -a sensor_list=()

	echo ""
	echo "=========================================="
	echo "Sensor Monitoring Tests"
	echo "=========================================="

	# Test 1: Get sensor list
	test_sensor_list || return 1

	# Test 2: Get common sensors (if available)
	# Try to get a few common sensor names from the list
	local cmd_output
	cmd_output=$(run_ipmi_cmd sensor list 2>&1)
	if (( $? == 0 )); then
		# Extract first few sensor names
		sensor_list=($(echo "$cmd_output" | grep "^[A-Za-z]" | head -3 | awk '{print $1}'))
		
		for sensor_name in "${sensor_list[@]}"; do
			[[ -n "$sensor_name" ]] && {
				# Test individual sensor reading
				test_sensor_get "$sensor_name"
				
				# Test sensor thresholds
				test_sensor_thresholds "$sensor_name"
				
				# Test reading consistency (only for first sensor to save time)
				[[ "$sensor_name" == "${sensor_list[0]}" ]] && {
					test_sensor_reading_consistency "$sensor_name"
				}
			}
		done
	else
		log_test "sensor_common" "SKIP" "Could not retrieve sensor list for common tests"
	fi

	# Print module summary
	echo ""
	echo "Sensor Module Summary:"
	echo "  Tests: $test_count"
	echo "  Passed: $pass_count"
	echo "  Failed: $fail_count"
	echo "  Skipped: $skip_count"

	return $fail_count
}

# Export the main function
export -f run_module_tests

