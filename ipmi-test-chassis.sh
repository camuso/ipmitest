#!/bin/bash
#
# ipmi-test-chassis - Chassis power control test module
#
# Tests IPMI chassis power control commands with idempotent operations
# to ensure safe, repeatable testing.
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
declare initial_power_state=""

#######################################
# Module Functions
#######################################

#** log_test: log test result with attribution
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

#** run_ipmi_cmd: execute IPMI command with error handling
#*
run_ipmi_cmd() {
	local cmd_output
	local -i cmd_status

	((DRY_RUN > 0)) && {
		echo "[DRY-RUN] ipmitool $*" >&2
		return 0
	}

	cmd_output=$(ipmitool -I lanplus -H "$BMC_HOST" -U "$BMC_USER" -P "$BMC_PASS" "$@" 2>&1)
	cmd_status=$?

	((VERBOSE > 1)) && echo "Command: ipmitool $*" >&2
	((VERBOSE > 1)) && echo "Output: $cmd_output" >&2

	return $cmd_status
}

#** get_power_state: get current chassis power state
#*
get_power_state() {
	local cmd_output

	cmd_output=$(run_ipmi_cmd chassis power status 2>&1)
	if echo "$cmd_output" | grep -qi "on"; then
		echo "on"
	elif echo "$cmd_output" | grep -qi "off"; then
		echo "off"
	else
		echo "unknown"
	fi
}

#** save_initial_state: save initial power state for restoration
#*
save_initial_state() {
	initial_power_state=$(get_power_state)
	log_test "state_save" "INFO" "Initial power state: $initial_power_state"
}

#** restore_initial_state: restore initial power state (idempotent)
#*
restore_initial_state() {
	local current_state

	[[ -z "$initial_power_state" ]] && return 0

	current_state=$(get_power_state)
	if [[ "$current_state" != "$initial_power_state" ]]; then
		log_test "state_restore" "INFO" "Restoring power state to: $initial_power_state"
		run_ipmi_cmd chassis power "$initial_power_state" >/dev/null 2>&1
		sleep 2
	else
		log_test "state_restore" "INFO" "Power state already at initial state"
	fi
}

#** test_chassis_status: test chassis status retrieval
#*
test_chassis_status() {
	local test_name="chassis_status"
	local cmd_output

	log_test "$test_name" "INFO" "Testing chassis status retrieval"

	cmd_output=$(run_ipmi_cmd chassis status 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(System Power|Power Overload|Power Interlock)"; then
			log_test "$test_name" "PASS" "Successfully retrieved chassis status"
		else
			log_test "$test_name" "FAIL" "Invalid chassis status format"
		fi
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_power_status: test power status command
#*
test_power_status() {
	local test_name="power_status"
	local cmd_output
	local power_state

	log_test "$test_name" "INFO" "Testing power status command"

	cmd_output=$(run_ipmi_cmd chassis power status 2>&1)
	local -i status=$?

	if ((status == 0)); then
		power_state=$(get_power_state)
		if [[ "$power_state" != "unknown" ]]; then
			log_test "$test_name" "PASS" "Power state: $power_state"
		else
			log_test "$test_name" "FAIL" "Could not determine power state"
		fi
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_power_cycle: test power cycle command (idempotent)
#*
test_power_cycle() {
	local test_name="power_cycle"
	local initial_state
	local cmd_output

	((DRY_RUN > 0)) && {
		log_test "$test_name" "SKIP" "Skipped in dry-run mode (destructive operation)"
		return 0
	}

	log_test "$test_name" "INFO" "Testing power cycle command"

	initial_state=$(get_power_state)
	if [[ "$initial_state" == "off" ]]; then
		log_test "$test_name" "SKIP" "System is off, cannot test power cycle"
		return 0
	fi

	cmd_output=$(run_ipmi_cmd chassis power cycle 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "Power cycle command accepted"
		sleep 3
		# Note: Actual cycle completion would require longer wait
	else
		log_test "$test_name" "FAIL" "Power cycle failed: $cmd_output"
	fi

	return $status
}

#** test_power_reset: test power reset command
#*
test_power_reset() {
	local test_name="power_reset"
	local initial_state
	local cmd_output

	((DRY_RUN > 0)) && {
		log_test "$test_name" "SKIP" "Skipped in dry-run mode (destructive operation)"
		return 0
	}

	log_test "$test_name" "INFO" "Testing power reset command"

	initial_state=$(get_power_state)
	if [[ "$initial_state" == "off" ]]; then
		log_test "$test_name" "SKIP" "System is off, cannot test power reset"
		return 0
	fi

	cmd_output=$(run_ipmi_cmd chassis power reset 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "Power reset command accepted"
	else
		log_test "$test_name" "FAIL" "Power reset failed: $cmd_output"
	fi

	return $status
}

#** test_power_soft: test soft power off command
#*
test_power_soft() {
	local test_name="power_soft"
	local cmd_output

	((DRY_RUN > 0)) && {
		log_test "$test_name" "SKIP" "Skipped in dry-run mode (destructive operation)"
		return 0
	}

	log_test "$test_name" "INFO" "Testing soft power off command"

	cmd_output=$(run_ipmi_cmd chassis power soft 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "Soft power off command accepted"
	else
		log_test "$test_name" "FAIL" "Soft power off failed: $cmd_output"
	fi

	return $status
}

#** run_module_tests: main test execution function for chassis module
#*
run_module_tests() {
	echo ""
	echo "=========================================="
	echo "Chassis Power Control Tests"
	echo "=========================================="

	# Save initial state for restoration
	save_initial_state

	# Test 1: Chassis status
	test_chassis_status

	# Test 2: Power status
	test_power_status

	# Test 3: Power cycle (if system is on)
	test_power_cycle

	# Test 4: Power reset (if system is on)
	test_power_reset

	# Test 5: Soft power off
	test_power_soft

	# Restore initial state (idempotent)
	restore_initial_state

	# Print module summary
	echo ""
	echo "Chassis Module Summary:"
	echo "  Tests: $test_count"
	echo "  Passed: $pass_count"
	echo "  Failed: $fail_count"
	echo "  Skipped: $skip_count"

	return $fail_count
}

# Export the main function
export -f run_module_tests

