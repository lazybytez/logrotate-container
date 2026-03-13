#!/bin/bash
#
# Main test runner for logrotate-container e2e tests.
#
# Usage:
#   ./e2e/run-tests.sh                      # run all suites
#   ./e2e/run-tests.sh 01_config_generation  # run a single suite
#
# Environment:
#   CONTAINER_RUNTIME  docker (default) or podman
#   IMAGE_NAME         image tag to build/use (default: logrotate-e2e-test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
IMAGE_NAME="${IMAGE_NAME:-logrotate-e2e-test}"
export CONTAINER_RUNTIME IMAGE_NAME

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Logrotate Container — E2E Tests"
echo "  Runtime: $CONTAINER_RUNTIME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Building image..."
$CONTAINER_RUNTIME build -f "$PROJECT_DIR/Containerfile" -t "$IMAGE_NAME" "$PROJECT_DIR" || {
  echo "ERROR: Image build failed." >&2
  exit 1
}
echo "Build complete."

suites_total=0
suites_passed=0
suites_failed=0
failed_names=()

# Determine which suites to run
if [ $# -gt 0 ]; then
  test_files=()
  for name in "$@"; do
    file="$SCRIPT_DIR/tests/${name}.sh"
    if [ ! -f "$file" ]; then
      echo "ERROR: Suite not found: $file" >&2
      exit 1
    fi
    test_files+=("$file")
  done
else
  test_files=("$SCRIPT_DIR"/tests/*.sh)
fi

for test_file in "${test_files[@]}"; do
  suite=$(basename "$test_file" .sh)
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "▶ $suite"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  suites_total=$((suites_total + 1))
  if bash "$test_file"; then
    suites_passed=$((suites_passed + 1))
  else
    suites_failed=$((suites_failed + 1))
    failed_names+=("$suite")
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Suites: $suites_total | Passed: $suites_passed | Failed: $suites_failed"

if [ ${#failed_names[@]} -gt 0 ]; then
  echo "  Failed: ${failed_names[*]}"
  exit 1
fi

echo "  All suites passed!"
