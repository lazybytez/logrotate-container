#!/bin/bash
# Tests for basic logrotate configuration generation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- Default configuration ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "config contains nomail directive"
assert_contains "$config" "nomail"
end_test

begin_test "config includes discovered log file path"
assert_contains "$config" "/logs/app.log"
end_test

begin_test "default rotate count is 5"
assert_contains "$config" "rotate 5"
end_test

begin_test "default mode is copytruncate"
assert_contains "$config" "copytruncate"
end_test

begin_test "default compression is nocompress"
assert_contains "$config" "nocompress"
end_test

begin_test "config includes missingok"
assert_contains "$config" "missingok"
end_test

begin_test "config does not contain olddir by default"
assert_not_contains "$config" "olddir"
end_test

container_stop "$cid"

# --- LOGROTATE_OLDDIR ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_OLDDIR="/archive")
config=$(get_config "$cid")

begin_test "LOGROTATE_OLDDIR adds olddir directive"
assert_contains "$config" "olddir /archive"
end_test

container_stop "$cid"

# --- Config is reset on startup (no stale entries) ---

dir=$(create_log_dir "fresh.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "config only contains current files (no stale entries)"
assert_contains "$config" "/logs/fresh.log"
assert_not_contains "$config" "/logs/old-stale.log"
end_test

container_stop "$cid"

finish_suite
