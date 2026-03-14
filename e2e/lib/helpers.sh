#!/bin/bash
#
# E2E test helpers for logrotate-container.
#
# Provides assertion functions, container management, and test lifecycle
# utilities. Source this file at the top of each test script.

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
IMAGE_NAME="${IMAGE_NAME:-logrotate-e2e-test}"
_CONTAINER_PREFIX="logrotate-e2e"

_TESTS=0
_PASSES=0
_FAILURES=0
_CURRENT_TEST=""
_TEST_FAILED=false
_CLEANUP_CONTAINERS=()
_CLEANUP_DIRS=()

_RED='\033[0;31m'
_GREEN='\033[0;32m'
_NC='\033[0m'

# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

begin_test() {
  _CURRENT_TEST="$1"
  _TESTS=$((_TESTS + 1))
  _TEST_FAILED=false
}

end_test() {
  if [ "$_TEST_FAILED" = false ]; then
    _PASSES=$((_PASSES + 1))
    echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST"
  fi
}

_mark_fail() {
  if [ "$_TEST_FAILED" = false ]; then
    _FAILURES=$((_FAILURES + 1))
    echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST"
  fi
  _TEST_FAILED=true
  echo -e "    ${_RED}→ $1${_NC}"
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

assert_contains() {
  if ! echo "$1" | grep -qF -- "$2"; then
    _mark_fail "Expected to contain: '$2'"
  fi
}

assert_matches() {
  if ! echo "$1" | grep -qE -- "$2"; then
    _mark_fail "Expected to match pattern: '$2'"
  fi
}

assert_not_contains() {
  if echo "$1" | grep -qF -- "$2"; then
    _mark_fail "Expected NOT to contain: '$2'"
  fi
}

assert_equals() {
  if [ "$1" != "$2" ]; then
    _mark_fail "Expected '$2' but got '$1'"
  fi
}

assert_file_exists_in_container() {
  local cid="$1"
  local path="$2"
  if ! $CONTAINER_RUNTIME exec "$cid" test -e "$path" 2>/dev/null; then
    _mark_fail "Expected file to exist in container: $path"
  fi
}

assert_file_not_exists_in_container() {
  local cid="$1"
  local path="$2"
  if $CONTAINER_RUNTIME exec "$cid" test -e "$path" 2>/dev/null; then
    _mark_fail "Expected file NOT to exist in container: $path"
  fi
}

# ---------------------------------------------------------------------------
# Container helpers
# ---------------------------------------------------------------------------

# Create a temp directory and populate it with the given files.
# Each argument is a relative file path; parent directories are created.
# Prints the absolute path to the temp directory.
create_log_dir() {
  local dir
  dir=$(mktemp -d "/tmp/${_CONTAINER_PREFIX}-XXXXXX")
  _CLEANUP_DIRS+=("$dir")
  for f in "$@"; do
    mkdir -p "$(dirname "$dir/$f")"
    echo "test log line $(date +%s%N)" > "$dir/$f"
  done
  echo "$dir"
}

_wait_for_config() {
  local cid="$1"
  local timeout="${2:-10}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if $CONTAINER_RUNTIME exec "$cid" test -e /usr/bin/logrotate.d/logrotate.conf 2>/dev/null; then
      return 0
    fi
    sleep 0.5
    elapsed=$((elapsed + 1))
  done
  echo "WARNING: timed out waiting for logrotate config" >&2
}

_wait_for_ofelia() {
  local cid="$1"
  local timeout="${2:-15}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if $CONTAINER_RUNTIME exec "$cid" sh -c 'test -d /etc/ofelia && ls /etc/ofelia/*.ini' 2>/dev/null | grep -q '.ini'; then
      return 0
    fi
    sleep 0.5
    elapsed=$((elapsed + 1))
  done
  echo "WARNING: timed out waiting for ofelia config" >&2
}

# Start the container with CMD="sleep 120" so the entrypoint generates
# config and then keeps the container alive for inspection.
# Pass any extra docker flags (e.g. -e, -v) as arguments.
# Prints the container ID.
start_container() {
  local name="${_CONTAINER_PREFIX}-$$-${RANDOM}"
  local cid
  cid=$($CONTAINER_RUNTIME run -d --name "$name" "$@" "$IMAGE_NAME" sleep 120)
  _CLEANUP_CONTAINERS+=("$cid")
  _wait_for_config "$cid" 10
  echo "$cid"
}

# Start the container with CMD="cron" (launches ofelia).
# Prints the container ID.
start_container_cron() {
  local name="${_CONTAINER_PREFIX}-$$-${RANDOM}"
  local cid
  cid=$($CONTAINER_RUNTIME run -d --name "$name" "$@" "$IMAGE_NAME" cron)
  _CLEANUP_CONTAINERS+=("$cid")
  _wait_for_ofelia "$cid" 15
  echo "$cid"
}

# Read the generated logrotate config from a running container.
get_config() {
  $CONTAINER_RUNTIME exec "$1" cat /usr/bin/logrotate.d/logrotate.conf 2>/dev/null
}

# Read the ofelia schedule config from a running container.
get_ofelia_config() {
  $CONTAINER_RUNTIME exec "$1" sh -c 'cat /etc/ofelia/*.ini 2>/dev/null'
}

# Execute a command inside a running container.
container_exec() {
  local cid="$1"
  shift
  $CONTAINER_RUNTIME exec "$cid" "$@"
}

# List files in a container directory.
container_ls() {
  $CONTAINER_RUNTIME exec "$1" ls "$2" 2>/dev/null
}

# Capture full stdout/stderr from the container logs.
container_logs() {
  $CONTAINER_RUNTIME logs "$1" 2>&1
}

# Stop and remove a specific container.
container_stop() {
  $CONTAINER_RUNTIME rm -f "$1" >/dev/null 2>&1 || true
}

# Remove a temp directory.
cleanup_dir() {
  [ -n "$1" ] && [ -d "$1" ] && rm -rf "$1"
}

# Clean up all tracked containers and temp dirs.
cleanup_all() {
  for cid in "${_CLEANUP_CONTAINERS[@]}"; do
    container_stop "$cid"
  done
  for d in "${_CLEANUP_DIRS[@]}"; do
    cleanup_dir "$d"
  done
  _CLEANUP_CONTAINERS=()
  _CLEANUP_DIRS=()
}

# Print suite summary, clean up, and exit.
finish_suite() {
  cleanup_all
  echo ""
  if [ "$_FAILURES" -gt 0 ]; then
    echo -e "  ${_RED}${_FAILURES} of ${_TESTS} tests failed${_NC}"
    exit 1
  fi
  echo -e "  ${_GREEN}All ${_TESTS} tests passed${_NC}"
  exit 0
}

trap cleanup_all EXIT
