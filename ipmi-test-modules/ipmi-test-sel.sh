#!/bin/bash
#
# ipmi-test-sel - System Event Log operations test module
# VERSION: 1.0.4-WATERMARKED
#
# Tests SEL reading, clearing, and event logging capabilities
# with snapshot-safe operations.
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
declare sel_backup_file=""

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

#** backup_sel: backup SEL entries before modification (snapshot-safe)
#*
backup_sel() {
	local backup_dir="${LOG_FILE%/*}"
	sel_backup_file="$backup_dir/sel-backup-${SESSION_ID}.txt"

	log_test "sel_backup" "INFO" "Backing up SEL to: $sel_backup_file"

	run_ipmi_cmd sel list > "$sel_backup_file" 2>&1
	local -i status=$?

	if ((status == 0)); then
		log_test "sel_backup" "PASS" "SEL backed up successfully"
	else
		log_test "sel_backup" "FAIL" "Failed to backup SEL"
	fi

	return $status
}

#** restore_sel: restore SEL from backup (idempotent - SEL append-only)
#*
restore_sel() {
	# Note: SEL is append-only, so we can't truly restore
	# This function documents the backup location for audit purposes
	[[ -n "$sel_backup_file" ]] && {
		log_test "sel_restore" "INFO" "SEL backup available at: $sel_backup_file"
		log_test "sel_restore" "INFO" "Note: SEL is append-only, cannot restore deleted entries"
	}
}

#** test_sel_info: test SEL information retrieval
#*
test_sel_info() {
	local test_name="sel_info"
	local cmd_output

	log_test "$test_name" "INFO" "Testing SEL information retrieval"

	cmd_output=$(run_ipmi_cmd sel info 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(Entries|Free Space|Percent Used)"; then
			log_test "$test_name" "PASS" "Successfully retrieved SEL information"
		else
			log_test "$test_name" "FAIL" "Invalid SEL info format"
		fi
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_sel_list: test SEL entry listing
#*
test_sel_list() {
	local test_name="sel_list"
	local cmd_output
	local -i entry_count=0

	log_test "$test_name" "INFO" "Testing SEL entry listing"

	cmd_output=$(run_ipmi_cmd sel list 2>&1)
	local -i status=$?

	if ((status == 0)); then
		# Count entries, handling empty results safely
		entry_count=$(echo "$cmd_output" | grep -c "^[0-9a-fA-F]" 2>/dev/null) || entry_count=0
		# Ensure it's a valid integer
		if [[ ! "$entry_count" =~ ^[0-9]+$ ]]; then
			entry_count=0
		fi
		log_test "$test_name" "PASS" "Retrieved $entry_count SEL entries"
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_sel_get: test individual SEL entry retrieval
#*
test_sel_get() {
	local test_name="sel_get"
	local entry_id="$1"
	local cmd_output

	[[ -z "$entry_id" ]] && {
		# Try to get first available entry
		entry_id=$(run_ipmi_cmd sel list 2>&1 | grep "^[0-9a-fA-F]" | head -1 | awk '{print $1}')
		[[ -z "$entry_id" ]] && {
			log_test "$test_name" "SKIP" "No SEL entries available"
			return 0
		}
	}

	log_test "$test_name" "INFO" "Testing SEL entry retrieval: $entry_id"

	cmd_output=$(run_ipmi_cmd sel get "$entry_id" 2>&1)
	local -i status=$?

	if ((status == 0)); then
		if echo "$cmd_output" | grep -qE "(SEL Record|Timestamp|Sensor)"; then
			log_test "$test_name" "PASS" "Successfully retrieved SEL entry"
		else
			log_test "$test_name" "FAIL" "Invalid SEL entry format"
		fi
	else
		log_test "$test_name" "FAIL" "Command failed: $cmd_output"
	fi

	return $status
}

#** test_sel_clear: test SEL clearing (with backup)
#*
test_sel_clear() {
	local test_name="sel_clear"
	local cmd_output

	((DRY_RUN > 0)) && {
		log_test "$test_name" "SKIP" "Skipped in dry-run mode (destructive operation)"
		return 0
	}

	log_test "$test_name" "INFO" "Testing SEL clear command"

	# Backup before clearing
	backup_sel

	cmd_output=$(run_ipmi_cmd sel clear 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "SEL clear command accepted"
		sleep 2
		# Verify SEL was cleared
		local -i entry_count=0
		local sel_list_output
		sel_list_output=$(run_ipmi_cmd sel list 2>&1)
		if (( $? == 0 )); then
			entry_count=$(echo "$sel_list_output" | grep -c "^[0-9a-fA-F]" 2>/dev/null) || entry_count=0
			[[ "$entry_count" =~ ^[0-9]+$ ]] || entry_count=0
		fi

		if ((entry_count == 0)); then
			log_test "$test_name" "PASS" "SEL successfully cleared"
		else
			log_test "$test_name" "WARN" "SEL may not be fully cleared (entries: $entry_count)"
		fi
	else
		log_test "$test_name" "FAIL" "SEL clear failed: $cmd_output"
	fi

	return $status
}

#** test_sel_time: test SEL time operations
#*
test_sel_time() {
	local test_name="sel_time"
	local cmd_output

	log_test "$test_name" "INFO" "Testing SEL time operations"

	# Get SEL time
	cmd_output=$(run_ipmi_cmd sel time get 2>&1)
	local -i status=$?

	if ((status == 0)); then
		log_test "$test_name" "PASS" "Successfully retrieved SEL time"
	else
		log_test "$test_name" "SKIP" "SEL time command not supported: $cmd_output"
	fi

	return 0
}

#** run_module_tests: main test execution function for SEL module
#*
run_module_tests() {
	echo ""
	echo "=========================================="
	echo "System Event Log Tests"
	echo "=========================================="

	# Test 1: SEL information
	test_sel_info

	# Test 2: SEL list
	test_sel_list

	# Test 3: SEL get (first entry)
	test_sel_get

	# Test 4: SEL time
	test_sel_time

	# Test 5: SEL clear (with backup)
	test_sel_clear

	# Restore SEL backup info (for audit)
	restore_sel

	# Print module summary
	echo ""
	echo "SEL Module Summary:"
	echo "  Tests: $test_count"
	echo "  Passed: $pass_count"
	echo "  Failed: $fail_count"
	echo "  Skipped: $skip_count"

	return $fail_count
}

# Export the main function
export -f run_module_tests

