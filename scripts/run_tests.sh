#!/usr/bin/env bash

set -euo pipefail

TEST_SCOPE="${1:-all}"

echo "Requested test scope: ${TEST_SCOPE}"
echo "Documented IRIS tests should be run inside the ${IRIS_CONTAINER_NAME:-iris111} container."
echo "Suggested commands from the docs:"
echo "  do ^test_bronze"
echo "  do ^test_silver"
echo "  do ^test_gold"
echo "  do ^test_api"
echo "  do ^test_e2e"
