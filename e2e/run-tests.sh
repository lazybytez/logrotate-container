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
#   CONTAINERFILE      Containerfile to build (default: Containerfile.alpine)
#   IMAGE_NAME         image tag to build/use (default: logrotate-e2e-test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.alpine}"
IMAGE_NAME="${IMAGE_NAME:-logrotate-e2e-test}"
export CONTAINER_RUNTIME IMAGE_NAME

FLAVOUR="${CONTAINERFILE#Containerfile.}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Logrotate Container — E2E Tests"
echo "  Runtime: $CONTAINER_RUNTIME"
echo "  Flavour: $FLAVOUR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Building image..."
$CONTAINER_RUNTIME build -f "$PROJECT_DIR/$CONTAINERFILE" -t "$IMAGE_NAME" "$PROJECT_DIR" || {
  echo "ERROR: Image build failed." >&2
  exit 1
}
echo "Build complete."

suites_total=0
suites_passed=0
suites_failed=0
failed_names=()
suite_results=()

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
    suite_results+=("pass:$suite")
  else
    suites_failed=$((suites_failed + 1))
    failed_names+=("$suite")
    suite_results+=("fail:$suite")
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Suites: $suites_total | Passed: $suites_passed | Failed: $suites_failed"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    if [ ${#failed_names[@]} -gt 0 ]; then
      echo "## :x: E2E Tests ($FLAVOUR) — ${suites_failed} failed"
    else
      echo "## :white_check_mark: E2E Tests ($FLAVOUR) — All passed"
    fi
    echo ""
    echo "| Suite | Result |"
    echo "|---|---|"
    for entry in "${suite_results[@]}"; do
      status="${entry%%:*}"
      name="${entry#*:}"
      if [ "$status" = "pass" ]; then
        echo "| $name | :white_check_mark: Pass |"
      else
        echo "| $name | :x: Fail |"
      fi
    done
    echo ""
    echo "**Suites:** $suites_total | **Passed:** $suites_passed | **Failed:** $suites_failed"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ ${#failed_names[@]} -gt 0 ]; then
  echo "  Failed: ${failed_names[*]}"
  exit 1
fi

echo "  All suites passed!"
