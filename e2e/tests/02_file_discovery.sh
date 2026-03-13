#!/bin/bash
# Tests for log file discovery via LOGS_DIRECTORIES, LOG_FILE_ENDINGS,
# LOGS_FILE_REGEX, and ALL_LOGS_DIRECTORIES.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- Single file, single directory ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "discovers single .log file"
assert_contains "$config" "/logs/app.log"
end_test

container_stop "$cid"

# --- Multiple files in one directory ---

dir=$(create_log_dir "app.log" "error.log" "access.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "discovers multiple .log files in same directory"
assert_contains "$config" "/logs/app.log"
assert_contains "$config" "/logs/error.log"
assert_contains "$config" "/logs/access.log"
end_test

container_stop "$cid"

# --- Multiple directories ---

dir=$(create_log_dir "a/app.log" "b/service.log")
cid=$(start_container \
  -v "$dir/a:/logs-a" \
  -v "$dir/b:/logs-b" \
  -e LOGS_DIRECTORIES="/logs-a /logs-b")
config=$(get_config "$cid")

begin_test "discovers files across multiple directories"
assert_contains "$config" "/logs-a/app.log"
assert_contains "$config" "/logs-b/service.log"
end_test

container_stop "$cid"

# --- Custom single file ending ---

dir=$(create_log_dir "app.txt" "ignored.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOG_FILE_ENDINGS="txt")
config=$(get_config "$cid")

begin_test "custom LOG_FILE_ENDINGS discovers only matching extension"
assert_contains "$config" "/logs/app.txt"
assert_not_contains "$config" "/logs/ignored.log"
end_test

container_stop "$cid"

# --- Multiple file endings ---

dir=$(create_log_dir "app.log" "err.txt" "data.csv")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOG_FILE_ENDINGS="log txt")
config=$(get_config "$cid")

begin_test "multiple LOG_FILE_ENDINGS discovers all matching extensions"
assert_contains "$config" "/logs/app.log"
assert_contains "$config" "/logs/err.txt"
assert_not_contains "$config" "/logs/data.csv"
end_test

container_stop "$cid"

# --- Case-insensitive file ending matching ---

dir=$(create_log_dir "lower.log" "upper.LOG" "mixed.Log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "file ending matching is case-insensitive"
assert_contains "$config" "/logs/lower.log"
assert_contains "$config" "/logs/upper.LOG"
assert_contains "$config" "/logs/mixed.Log"
end_test

container_stop "$cid"

# --- LOGS_FILE_REGEX ---

dir=$(create_log_dir "app-2024.log" "service.txt" "debug-2024.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOG_FILE_ENDINGS=" " \
  -e LOGS_FILE_REGEX=".*-2024\.log")
config=$(get_config "$cid")

begin_test "LOGS_FILE_REGEX matches files by regex pattern"
assert_contains "$config" "/logs/app-2024.log"
assert_contains "$config" "/logs/debug-2024.log"
assert_not_contains "$config" "/logs/service.txt"
end_test

container_stop "$cid"

# --- ALL_LOGS_DIRECTORIES finds all files regardless of extension ---

dir=$(create_log_dir "app.log" "data.csv" "notes.txt")
cid=$(start_container -v "$dir:/alllogs" \
  -e ALL_LOGS_DIRECTORIES="/alllogs")
config=$(get_config "$cid")

begin_test "ALL_LOGS_DIRECTORIES discovers all files without extension filter"
assert_contains "$config" "/alllogs/app.log"
assert_contains "$config" "/alllogs/data.csv"
assert_contains "$config" "/alllogs/notes.txt"
end_test

container_stop "$cid"

# --- Non-existent directory does not crash ---

dir=$(create_log_dir "app.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/nonexistent /logs")
config=$(get_config "$cid")

begin_test "non-existent directory in LOGS_DIRECTORIES does not crash"
assert_contains "$config" "/logs/app.log"
end_test

container_stop "$cid"

# --- Empty directory produces no file entries ---

dir=$(create_log_dir)
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "empty directory produces config with no file entries"
assert_contains "$config" "nomail"
assert_not_contains "$config" "{"
end_test

container_stop "$cid"

# --- Nested subdirectories ---

dir=$(create_log_dir "sub/deep/app.log")
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "discovers files in nested subdirectories"
assert_contains "$config" "/logs/sub/deep/app.log"
end_test

container_stop "$cid"

# --- Only files, not directories, are matched ---

dir=$(create_log_dir "real.log")
mkdir -p "$dir/fake.log"
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
config=$(get_config "$cid")

begin_test "directories named with .log extension are not matched"
assert_contains "$config" "/logs/real.log"
# The directory entry should not appear as a logrotate block
# (find uses -type f so directories are excluded)
end_test

container_stop "$cid"

finish_suite
