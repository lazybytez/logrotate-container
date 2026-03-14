#!/bin/bash
# Tests for rotation configuration directives:
# LOGROTATE_COPIES, SIZE, MINSIZE, MAXAGE, MODE, DATEFORMAT, INTERVAL.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- LOGROTATE_COPIES ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COPIES="10")
config=$(get_config "$cid")

begin_test "LOGROTATE_COPIES sets custom rotate count"
assert_contains "$config" "rotate 10"
assert_not_contains "$config" "rotate 5"
end_test

container_stop "$cid"

# --- LOGROTATE_SIZE ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_SIZE="100M")
config=$(get_config "$cid")

begin_test "LOGROTATE_SIZE adds size directive"
assert_contains "$config" "size 100M"
end_test

container_stop "$cid"

# --- LOGROTATE_MINSIZE ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_MINSIZE="10M")
config=$(get_config "$cid")

begin_test "LOGROTATE_MINSIZE adds minsize directive"
assert_contains "$config" "minsize 10M"
end_test

container_stop "$cid"

# --- LOGROTATE_MAXAGE ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_MAXAGE="30")
config=$(get_config "$cid")

begin_test "LOGROTATE_MAXAGE adds maxage directive"
assert_contains "$config" "maxage 30"
end_test

container_stop "$cid"

# --- Custom LOGROTATE_MODE ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_MODE="create")
config=$(get_config "$cid")

begin_test "LOGROTATE_MODE overrides default copytruncate"
assert_contains "$config" "create"
assert_not_contains "$config" "copytruncate"
end_test

container_stop "$cid"

# --- LOGROTATE_DATEFORMAT ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_DATEFORMAT="-%Y%m%d")
config=$(get_config "$cid")

begin_test "LOGROTATE_DATEFORMAT adds dateext and dateformat directives"
assert_contains "$config" "dateext"
assert_contains "$config" "dateformat -%Y%m%d"
end_test

container_stop "$cid"

# --- No dateext without LOGROTATE_DATEFORMAT ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "no dateext directive without LOGROTATE_DATEFORMAT"
assert_not_contains "$config" "dateext"
assert_not_contains "$config" "dateformat"
end_test

container_stop "$cid"

# --- LOGROTATE_INTERVAL in per-file config ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="weekly")
config=$(get_config "$cid")

begin_test "LOGROTATE_INTERVAL appears in per-file config block"
assert_contains "$config" "weekly"
end_test

container_stop "$cid"

# --- Multiple settings combined ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COPIES="3" \
  -e LOGROTATE_SIZE="50M" \
  -e LOGROTATE_MAXAGE="7" \
  -e LOGROTATE_MINSIZE="1M" \
  -e LOGROTATE_DATEFORMAT="-%Y%m%d")
config=$(get_config "$cid")

begin_test "multiple rotation settings combine correctly"
assert_contains "$config" "rotate 3"
assert_contains "$config" "size 50M"
assert_contains "$config" "maxage 7"
assert_contains "$config" "minsize 1M"
assert_contains "$config" "dateext"
assert_contains "$config" "dateformat -%Y%m%d"
end_test

container_stop "$cid"

finish_suite
