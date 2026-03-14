#!/bin/bash
# Tests for file ownership handling (su directive in logrotate config).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- su directive present for root-owned file ---

cid=$(start_container -e LOGS_DIRECTORIES="/test-logs")

# Create file as root inside the container
container_exec "$cid" mkdir -p /test-logs
container_exec "$cid" sh -c 'echo "root log line" > /test-logs/root.log'
container_exec "$cid" bash /usr/bin/logrotate.d/update-logrotate.sh
config=$(get_config "$cid")

begin_test "su directive present for root-owned file"
assert_contains "$config" "/test-logs/root.log"
assert_matches "$config" "su root root"
end_test

container_stop "$cid"

# --- su directive present for file with known owner ---

cid=$(start_container -e LOGS_DIRECTORIES="/test-logs")

container_exec "$cid" mkdir -p /test-logs
container_exec "$cid" sh -c 'echo "owned log line" > /test-logs/owned.log'
container_exec "$cid" chown root:root /test-logs/owned.log
container_exec "$cid" bash /usr/bin/logrotate.d/update-logrotate.sh
config=$(get_config "$cid")

begin_test "su directive present for file with known owner"
assert_contains "$config" "/test-logs/owned.log"
assert_matches "$config" "su root root"
end_test

container_stop "$cid"

# --- su directive for logrotate user (UID 1000) ---

cid=$(start_container -e LOGS_DIRECTORIES="/test-logs")

container_exec "$cid" mkdir -p /test-logs
container_exec "$cid" sh -c 'echo "logrotate log" > /test-logs/user.log'
container_exec "$cid" chown logrotate:logrotate /test-logs/user.log
container_exec "$cid" bash /usr/bin/logrotate.d/update-logrotate.sh
config=$(get_config "$cid")

begin_test "su directive uses logrotate user when file owned by logrotate"
assert_contains "$config" "su logrotate logrotate"
end_test

container_stop "$cid"

# --- Mixed ownership across files ---

cid=$(start_container -e LOGS_DIRECTORIES="/test-logs")

container_exec "$cid" mkdir -p /test-logs
container_exec "$cid" sh -c 'echo "root log" > /test-logs/root.log'
container_exec "$cid" sh -c 'echo "user log" > /test-logs/user.log'
container_exec "$cid" chown logrotate:logrotate /test-logs/user.log
container_exec "$cid" bash /usr/bin/logrotate.d/update-logrotate.sh
config=$(get_config "$cid")

begin_test "different files can have different su directives"
assert_contains "$config" "/test-logs/root.log"
assert_contains "$config" "/test-logs/user.log"
assert_contains "$config" "su root root"
assert_contains "$config" "su logrotate logrotate"
end_test

container_stop "$cid"

finish_suite
