#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${WORKSPACE_DIR}/data/pos_feed"
mkdir -p "${WORKSPACE_DIR}/tests/objectscript"
mkdir -p "${WORKSPACE_DIR}/frontend/src"

if [[ ! -f "${WORKSPACE_DIR}/.env.docker" ]]; then
  cat > "${WORKSPACE_DIR}/.env.docker" <<EOF
IRIS_IMAGE=intersystemsdc/iris-community:2024.1-final
IRIS_CONTAINER_NAME=iris111
IRIS_PORT=52773
IRIS_PASSWORD=Demo123456!
WORKSPACE_DIR=${WORKSPACE_DIR}
EOF
fi

echo "IRIS workspace scaffold ready at ${WORKSPACE_DIR}."
echo "Start the container with: docker compose --env-file .env.docker up -d"
