#!/bin/bash
# Tests for pre-rotation and post-rotation command hooks:
# LOGROTATE_PREROTATE_COMMAND, LOGROTATE_POSTROTATE_COMMAND.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- Prerotate command only ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_PREROTATE_COMMAND="/usr/bin/notify pre")
config=$(get_config "$cid")

begin_test "LOGROTATE_PREROTATE_COMMAND adds prerotate block"
assert_contains "$config" "prerotate"
assert_contains "$config" "/usr/bin/notify pre"
assert_contains "$config" "endscript"
end_test

container_stop "$cid"

# --- Postrotate command only ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_POSTROTATE_COMMAND="/usr/bin/notify post")
config=$(get_config "$cid")

begin_test "LOGROTATE_POSTROTATE_COMMAND adds postrotate block"
assert_contains "$config" "postrotate"
assert_contains "$config" "/usr/bin/notify post"
assert_contains "$config" "endscript"
end_test

container_stop "$cid"

# --- Both pre and post rotate commands ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_PREROTATE_COMMAND="echo before" \
  -e LOGROTATE_POSTROTATE_COMMAND="echo after")
config=$(get_config "$cid")

begin_test "both prerotate and postrotate appear in config"
assert_contains "$config" "prerotate"
assert_contains "$config" "echo before"
assert_contains "$config" "postrotate"
assert_contains "$config" "echo after"
end_test

container_stop "$cid"

# --- Neither pre nor post rotate ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "no prerotate/postrotate blocks without commands"
assert_not_contains "$config" "prerotate"
assert_not_contains "$config" "postrotate"
assert_not_contains "$config" "endscript"
end_test

container_stop "$cid"

finish_suite
