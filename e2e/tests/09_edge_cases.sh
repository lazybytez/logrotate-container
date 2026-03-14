#!/bin/bash
# Tests for edge cases, debug features, and less common configurations.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- DEBUG=true produces trace output ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e DEBUG="true")
logs=$(container_logs "$cid")

begin_test "DEBUG=true enables bash trace output (set -x)"
assert_matches "$logs" "\\+"
end_test

container_stop "$cid"

# --- DELAYED_START delays startup ---

dir=$(create_log_dir "app.log")
name="${_CONTAINER_PREFIX}-$$-delay-${RANDOM}"
start_time=$(date +%s)
$CONTAINER_RUNTIME run --rm --name "$name" \
  -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e DELAYED_START="3" \
  "$IMAGE_NAME" echo "delayed-done" > /dev/null 2>&1
end_time=$(date +%s)
elapsed=$((end_time - start_time))

begin_test "DELAYED_START delays container startup"
if [ "$elapsed" -lt 3 ]; then
  _mark_fail "Expected at least 3s elapsed but got ${elapsed}s"
fi
end_test

# --- Custom command instead of cron ---

dir=$(create_log_dir "app.log")
name="${_CONTAINER_PREFIX}-$$-custom-${RANDOM}"
output=$($CONTAINER_RUNTIME run --rm --name "$name" \
  -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  "$IMAGE_NAME" echo "custom-command-executed" 2>&1)

begin_test "custom CMD executes instead of cron"
assert_contains "$output" "custom-command-executed"
end_test

# --- LOGROTATE_PARAMETERS adds flags to logrotate command ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_PARAMETERS="vf")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_PARAMETERS adds flags to logrotate command"
assert_contains "$ofelia" "-vf"
end_test

container_stop "$cid"

# --- LOGROTATE_STATUSFILE custom path ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_STATUSFILE="/tmp/custom.status")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_STATUSFILE sets custom state file path"
assert_contains "$ofelia" "--state=/tmp/custom.status"
end_test

container_stop "$cid"

# --- Default LOGROTATE_STATUSFILE path ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
ofelia=$(get_ofelia_config "$cid")

begin_test "default status file path is /logrotate-status/logrotate.status"
assert_contains "$ofelia" "--state=/logrotate-status/logrotate.status"
end_test

container_stop "$cid"

# --- Build metadata environment variables ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
version=$(container_exec "$cid" printenv LOGROTATE_CONTAINER_VERSION 2>/dev/null)
commit=$(container_exec "$cid" printenv LOGROTATE_CONTAINER_BUILD_COMMIT 2>/dev/null)

begin_test "build metadata environment variables are set"
# Version defaults to "edge" and commit to "unknown" during local builds
if [ -z "$version" ]; then
  _mark_fail "LOGROTATE_CONTAINER_VERSION is not set"
fi
if [ -z "$commit" ]; then
  _mark_fail "LOGROTATE_CONTAINER_BUILD_COMMIT is not set"
fi
end_test

container_stop "$cid"

# --- LOGROTATE_LOGFILE configuration in ofelia command ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_LOGFILE="/var/log/logrotate.log")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_LOGFILE pipes output to log file via tee"
assert_contains "$ofelia" "tee -a"
assert_contains "$ofelia" "/var/log/logrotate.log"
end_test

container_stop "$cid"

# --- Container with no matching files still starts ---

dir=$(create_log_dir "readme.txt")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "container with no matching .log files still starts and creates valid config"
assert_contains "$config" "nomail"
assert_not_contains "$config" "readme.txt"
end_test

container_stop "$cid"

# --- Multiple log files get individual config blocks ---

dir=$(create_log_dir "app.log" "error.log" "access.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "each discovered file gets its own config block"
# Count the number of opening braces (one per file block)
brace_count=$(echo "$config" | grep -c '{' || true)
assert_equals "$brace_count" "3"
end_test

container_stop "$cid"

# --- SYSLOGGER configuration in ofelia command ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e SYSLOGGER="true" \
  -e SYSLOGGER_TAG="logrotate-test")
ofelia=$(get_ofelia_config "$cid")

begin_test "SYSLOGGER pipes output to logger command with tag"
assert_contains "$ofelia" "logger"
assert_contains "$ofelia" "logrotate-test"
end_test

container_stop "$cid"

# --- SYSLOGGER takes priority over LOGROTATE_LOGFILE ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_LOGFILE="/var/log/logrotate.log" \
  -e SYSLOGGER="true")
ofelia=$(get_ofelia_config "$cid")

begin_test "SYSLOGGER takes priority over LOGROTATE_LOGFILE"
assert_contains "$ofelia" "logger"
assert_not_contains "$ofelia" "tee -a"
end_test

container_stop "$cid"

finish_suite
