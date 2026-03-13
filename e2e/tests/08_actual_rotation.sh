#!/bin/bash
# Tests for actual log rotation execution — verifying that logrotate
# correctly rotates, compresses, and manages log files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

LOGROTATE_CMD="/usr/sbin/logrotate -f --state=/logrotate-status/logrotate.status /usr/bin/logrotate.d/logrotate.conf"

# Helper: write N lines of content to a log file inside the container.
fill_log() {
  local cid="$1"
  local path="$2"
  local lines="${3:-100}"
  container_exec "$cid" sh -c \
    "for i in \$(seq 1 $lines); do echo \"Log line \$i - \$(date)\"; done >> $path"
}

# --- Force rotation creates rotated file ---

dir=$(create_log_dir "app.log")
fill_log_host() { for i in $(seq 1 100); do echo "line $i" >> "$1"; done; }
fill_log_host "$dir/app.log"
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")

container_exec "$cid" $LOGROTATE_CMD 2>/dev/null
files=$(container_ls "$cid" /logs)

begin_test "force rotation creates rotated file (app.log.1)"
assert_contains "$files" "app.log.1"
end_test

container_stop "$cid"

# --- Rotation with compression creates .gz file ---

dir=$(create_log_dir "app.log")
fill_log_host "$dir/app.log"
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COMPRESSION="compress" \
  -e LOGROTATE_DELAYCOMPRESS="false")

container_exec "$cid" $LOGROTATE_CMD 2>/dev/null
files=$(container_ls "$cid" /logs)

begin_test "rotation with compression creates .gz file"
assert_contains "$files" ".gz"
end_test

container_stop "$cid"

# --- Copytruncate preserves original file ---

dir=$(create_log_dir "app.log")
fill_log_host "$dir/app.log"
cid=$(start_container -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")

container_exec "$cid" $LOGROTATE_CMD 2>/dev/null

begin_test "copytruncate preserves original file after rotation"
assert_file_exists_in_container "$cid" "/logs/app.log"
assert_file_exists_in_container "$cid" "/logs/app.log.1"
end_test

container_stop "$cid"

# --- Rotation with olddir moves rotated file ---

dir=$(create_log_dir "app.log")
fill_log_host "$dir/app.log"
mkdir -p "$dir/archive"
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_OLDDIR="/logs/archive")

container_exec "$cid" $LOGROTATE_CMD 2>/dev/null
archive_files=$(container_ls "$cid" /logs/archive)

begin_test "rotation with LOGROTATE_OLDDIR moves rotated file to archive"
assert_contains "$archive_files" "app.log"
end_test

container_stop "$cid"

# --- Respects LOGROTATE_COPIES count ---

dir=$(create_log_dir "app.log")
fill_log_host "$dir/app.log"
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_COPIES="2")

# Rotate three times
for _ in 1 2 3; do
  fill_log "$cid" "/logs/app.log" 50
  container_exec "$cid" $LOGROTATE_CMD 2>/dev/null
done
files=$(container_ls "$cid" /logs)

begin_test "rotation respects LOGROTATE_COPIES limit"
assert_contains "$files" "app.log.1"
assert_contains "$files" "app.log.2"
assert_not_contains "$files" "app.log.3"
end_test

container_stop "$cid"

# --- Autoupdate discovers new files ---

dir=$(create_log_dir "initial.log")
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_AUTOUPDATE="true")

config_before=$(get_config "$cid")

# Add a new log file after initial config generation
container_exec "$cid" sh -c 'echo "new log" > /logs/dynamic.log'
container_exec "$cid" bash /usr/bin/logrotate.d/update-logrotate.sh
config_after=$(get_config "$cid")

begin_test "autoupdate discovers newly added log files"
assert_not_contains "$config_before" "/logs/dynamic.log"
assert_contains "$config_after" "/logs/dynamic.log"
end_test

container_stop "$cid"

# --- Rotation with dateformat uses dated extension ---

dir=$(create_log_dir "app.log")
fill_log_host "$dir/app.log"
cid=$(start_container -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_DATEFORMAT="-%Y%m%d")

container_exec "$cid" $LOGROTATE_CMD 2>/dev/null
files=$(container_ls "$cid" /logs)

begin_test "rotation with LOGROTATE_DATEFORMAT uses dated extension"
assert_matches "$files" "app\.log-[0-9]+"
end_test

container_stop "$cid"

finish_suite
