#!/bin/bash
# Tests for cron scheduling via ofelia:
# LOGROTATE_INTERVAL, LOGROTATE_CRONSCHEDULE, LOGROTATE_AUTOUPDATE.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/helpers.sh"

# --- Default schedule (no LOGROTATE_INTERVAL) ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
ofelia=$(get_ofelia_config "$cid")

begin_test "default schedule is '1 0 0 * * *'"
assert_contains "$ofelia" "schedule = 1 0 0 * * *"
end_test

container_stop "$cid"

# --- Interval: hourly ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="hourly")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_INTERVAL=hourly sets @hourly schedule"
assert_contains "$ofelia" "schedule = @hourly"
end_test

container_stop "$cid"

# --- Interval: daily ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="daily")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_INTERVAL=daily sets @daily schedule"
assert_contains "$ofelia" "schedule = @daily"
end_test

container_stop "$cid"

# --- Interval: weekly ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="weekly")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_INTERVAL=weekly sets @weekly schedule"
assert_contains "$ofelia" "schedule = @weekly"
end_test

container_stop "$cid"

# --- Interval: monthly ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="monthly")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_INTERVAL=monthly sets @monthly schedule"
assert_contains "$ofelia" "schedule = @monthly"
end_test

container_stop "$cid"

# --- Interval: yearly ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="yearly")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_INTERVAL=yearly sets @yearly schedule"
assert_contains "$ofelia" "schedule = @yearly"
end_test

container_stop "$cid"

# --- Invalid interval falls back to default ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="invalid_value")
ofelia=$(get_ofelia_config "$cid")

begin_test "invalid LOGROTATE_INTERVAL falls back to default schedule"
assert_contains "$ofelia" "schedule = 1 0 0 * * *"
end_test

container_stop "$cid"

# --- LOGROTATE_CRONSCHEDULE overrides LOGROTATE_INTERVAL ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_INTERVAL="daily" \
  -e LOGROTATE_CRONSCHEDULE="0 30 2 * * *")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_CRONSCHEDULE overrides LOGROTATE_INTERVAL"
assert_contains "$ofelia" "schedule = 0 30 2 * * *"
assert_not_contains "$ofelia" "@daily"
end_test

container_stop "$cid"

# --- LOGROTATE_AUTOUPDATE=true uses update-logrotate.sh ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_AUTOUPDATE="true")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_AUTOUPDATE=true chains update-logrotate.sh before logrotate"
assert_contains "$ofelia" "update-logrotate.sh"
assert_contains "$ofelia" "logrotate-with-autoupdate"
end_test

container_stop "$cid"

# --- LOGROTATE_AUTOUPDATE=false uses standard config ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" \
  -e LOGS_DIRECTORIES="/logs" \
  -e LOGROTATE_AUTOUPDATE="false")
ofelia=$(get_ofelia_config "$cid")

begin_test "LOGROTATE_AUTOUPDATE=false uses standard logrotate without update script"
assert_not_contains "$ofelia" "update-logrotate.sh"
assert_not_contains "$ofelia" "logrotate-with-autoupdate"
assert_contains "$ofelia" "logrotate"
end_test

container_stop "$cid"

# --- Ofelia config references the correct logrotate command ---

dir=$(create_log_dir "app.log")
cid=$(start_container_cron -v "$dir:/logs" -e LOGS_DIRECTORIES="/logs")
ofelia=$(get_ofelia_config "$cid")

begin_test "ofelia config contains logrotate command with config path"
assert_contains "$ofelia" "/usr/sbin/logrotate"
assert_contains "$ofelia" "/usr/bin/logrotate.d/logrotate.conf"
end_test

container_stop "$cid"

finish_suite
