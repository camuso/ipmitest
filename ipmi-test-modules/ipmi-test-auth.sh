#!/bin/bash
#
# ipmi-test-auth - Authentication and security test module
# Tests IPMI authentication mechanisms, user management, and security features.
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

#** test_auth_status: test authentication status
#*
test_auth_status() {
	local test_name="auth_status"
	local cmd_output

	log_test "$test_name" "INFO" "Testing authentication status"

	# Simple command to verify authentication works
	cmd_output=$(run_ipmi_cmd chassis status 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "Authentication successful"
	else
		if echo "$cmd_output" | grep -qi "authentication\|unauthorized\|password"; then
			log_test "$test_name" "FAIL" "Authentication failed: $cmd_output"
		else
			log_test "$test_name" "FAIL" "Command failed: $cmd_output"
		fi
	fi

	return $status
}

#** test_user_list: test user list retrieval
#*
test_user_list() {
	local test_name="user_list"
	local cmd_output
	local -i user_count=0

	log_test "$test_name" "INFO" "Testing user list retrieval"

	cmd_output=$(run_ipmi_cmd user list 2>&1)
	local -i status=$?

	if ((status == 0)); then
		user_count=$(echo "$cmd_output" | grep -c "^[0-9]" || echo "0")
		if ((user_count > 0)); then
			log_test "$test_name" "PASS" "Retrieved $user_count users"
		else
			log_test "$test_name" "FAIL" "No users found"
		fi
	else
		log_test "$test_name" "SKIP" "User list command not supported: $cmd_output"
	fi

	return 0
}

#** test_user_info: test user information retrieval
#*
test_user_info() {
	local test_name="user_info"
	local user_id="${BMC_USER:-1}"
	local cmd_output

	log_test "$test_name" "INFO" "Testing user info retrieval for user ID: $user_id"

	cmd_output=$(run_ipmi_cmd user list "$user_id" 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(User Name|User ID|Enabled)"; then
			log_test "$test_name" "PASS" "Successfully retrieved user information"
		else
			log_test "$test_name" "FAIL" "Invalid user info format"
		fi
	else
		log_test "$test_name" "SKIP" "User info command not supported: $cmd_output"
	fi

	return 0
}

#** test_channel_auth: test channel authentication capabilities
#*
test_channel_auth() {
	local test_name="channel_auth"
	local channel=1
	local cmd_output

	log_test "$test_name" "INFO" "Testing channel authentication capabilities"

	cmd_output=$(run_ipmi_cmd channel authcap "$channel" 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(Auth Type|IPMI|MD5|SHA1|SHA256)"; then
			log_test "$test_name" "PASS" "Retrieved channel authentication capabilities"
		else
			log_test "$test_name" "FAIL" "Invalid auth capabilities format"
		fi
	else
		log_test "$test_name" "SKIP" "Channel authcap command not supported: $cmd_output"
	fi

	return 0
}

#** test_session_info: test session information
#*
test_session_info() {
	local test_name="session_info"
	local cmd_output

	log_test "$test_name" "INFO" "Testing session information"

	cmd_output=$(run_ipmi_cmd session info 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(Session ID|User ID|Privilege)"; then
			log_test "$test_name" "PASS" "Successfully retrieved session information"
		else
			log_test "$test_name" "FAIL" "Invalid session info format"
		fi
	else
		log_test "$test_name" "SKIP" "Session info command not supported: $cmd_output"
	fi

	return 0
}

#** test_invalid_auth: test invalid authentication handling
#*
test_invalid_auth() {
	local test_name="invalid_auth"
	local cmd_output

	((DRY_RUN > 0)) && {
		log_test "$test_name" "SKIP" "Skipped in dry-run mode"
		return 0
	}

	log_test "$test_name" "INFO" "Testing invalid authentication rejection"

	# Try with wrong password
	cmd_output=$(ipmitool -I lanplus -H "$BMC_HOST" -U "$BMC_USER" -P "wrongpassword" chassis status 2>&1)
	local -i status=$?

	if ((status != 0)); then
		if echo "$cmd_output" | grep -qi "authentication\|unauthorized\|password"; then
			log_test "$test_name" "PASS" "Invalid authentication correctly rejected"
		else
			log_test "$test_name" "FAIL" "Unexpected error: $cmd_output"
		fi
	else
		log_test "$test_name" "FAIL" "Invalid authentication was accepted (security issue!)"
	fi

	return 0
}

#** run_module_tests: main test execution function for auth module
#*
run_module_tests() {
	echo ""
	echo "=========================================="
	echo "Authentication and Security Tests"
	echo "=========================================="

	# Test 1: Authentication status
	test_auth_status || return 1

	# Test 2: User list
	test_user_list

	# Test 3: User info
	test_user_info

	# Test 4: Channel authentication capabilities
	test_channel_auth

	# Test 5: Session information
	test_session_info

	# Test 6: Invalid authentication handling
	test_invalid_auth

	# Print module summary
	echo ""
	echo "Auth Module Summary:"
	echo "  Tests: $test_count"
	echo "  Passed: $pass_count"
	echo "  Failed: $fail_count"
	echo "  Skipped: $skip_count"

	return $fail_count
}

# Export the main function
export -f run_module_tests

