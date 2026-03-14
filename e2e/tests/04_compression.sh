#!/bin/bash
# Tests for compression configuration:
# LOGROTATE_COMPRESSION, LOGROTATE_DELAYCOMPRESS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- Default: nocompress, no delaycompress ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "default compression is nocompress"
assert_contains "$config" "nocompress"
assert_not_contains "$config" "delaycompress"
end_test

container_stop "$cid"

# --- Compression enabled → delaycompress added by default ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COMPRESSION="compress")
config=$(get_config "$cid")

begin_test "LOGROTATE_COMPRESSION=compress enables compression with delaycompress"
assert_contains "$config" "compress"
assert_contains "$config" "delaycompress"
assert_not_contains "$config" "nocompress"
end_test

container_stop "$cid"

# --- Compression with LOGROTATE_DELAYCOMPRESS=false ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COMPRESSION="compress" \
  -e LOGROTATE_DELAYCOMPRESS="false")
config=$(get_config "$cid")

begin_test "LOGROTATE_DELAYCOMPRESS=false disables delaycompress"
assert_contains "$config" "compress"
assert_not_contains "$config" "delaycompress"
end_test

container_stop "$cid"

# --- Explicit nocompress ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COMPRESSION="nocompress")
config=$(get_config "$cid")

begin_test "explicit LOGROTATE_COMPRESSION=nocompress disables compression"
assert_contains "$config" "nocompress"
assert_not_contains "$config" "delaycompress"
end_test

container_stop "$cid"

# --- nocompress never triggers delaycompress even when DELAYCOMPRESS != false ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COMPRESSION="nocompress" \
  -e LOGROTATE_DELAYCOMPRESS="true")
config=$(get_config "$cid")

begin_test "nocompress with LOGROTATE_DELAYCOMPRESS=true does not add delaycompress"
assert_contains "$config" "nocompress"
assert_not_contains "$config" "delaycompress"
end_test

container_stop "$cid"

finish_suite
