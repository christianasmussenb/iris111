#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to load classes into IRIS" >&2
  exit 1
fi

docker exec "${CONTAINER_NAME}" bash -lc 'if command -v iris >/dev/null 2>&1; then echo "IRIS container is up"; else echo "IRIS CLI not found inside container"; fi'

echo "Class sources are available under ${WORKSPACE_DIR}/src."
echo "Compile ObjectScript classes from the IRIS management tooling or the IRIS CLI inside the container."
