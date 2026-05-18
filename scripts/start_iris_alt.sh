#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_IMAGE="intersystemsdc/irishealth-ml-community:latest"
DEFAULT_CONTAINER_NAME="iris111-alt"
DEFAULT_PORT="52774"
DEFAULT_PROJECT_NAME="iris111-alt"
DEFAULT_PASSWORD="Demo123456!"

usage() {
  cat <<'EOF'
Usage: ./scripts/start_iris_alt.sh [options]

Start a second IRIS container for this workspace without colliding with the
default iris111 instance.

Options:
  -p, --port PORT           Host port to expose (default: 52774)
  -n, --name NAME           Container name (default: iris111-alt)
  -P, --project NAME        Compose project name (default: iris111-alt)
  -i, --image IMAGE         IRIS image (default: intersystemsdc/irishealth-ml-community:latest)
  -w, --workspace PATH      Workspace root to mount (default: repo root)
  -h, --help                Show this help

Environment variables with the same names can also be used.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port)
      IRIS_PORT="$2"
      shift 2
      ;;
    -n|--name)
      IRIS_CONTAINER_NAME="$2"
      shift 2
      ;;
    -P|--project|--project-name)
      IRIS_PROJECT_NAME="$2"
      shift 2
      ;;
    -i|--image)
      IRIS_IMAGE="$2"
      shift 2
      ;;
    -w|--workspace)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

: "${IRIS_IMAGE:=${DEFAULT_IMAGE}}"
: "${IRIS_CONTAINER_NAME:=${DEFAULT_CONTAINER_NAME}}"
: "${IRIS_PORT:=${DEFAULT_PORT}}"
: "${IRIS_PROJECT_NAME:=${DEFAULT_PROJECT_NAME}}"
: "${IRIS_PASSWORD:=${DEFAULT_PASSWORD}}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to start IRIS" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is required to start IRIS" >&2
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"${IRIS_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Host port ${IRIS_PORT} is already in use. Re-run with a different IRIS_PORT." >&2
    exit 1
  fi
fi

echo "Starting IRIS container '${IRIS_CONTAINER_NAME}' on http://localhost:${IRIS_PORT}/csp/system/"
echo "Image: ${IRIS_IMAGE}"

IRIS_IMAGE="${IRIS_IMAGE}" \
IRIS_CONTAINER_NAME="${IRIS_CONTAINER_NAME}" \
IRIS_PORT="${IRIS_PORT}" \
IRIS_PASSWORD="${IRIS_PASSWORD}" \
WORKSPACE_DIR="${WORKSPACE_DIR}" \
  docker compose -p "${IRIS_PROJECT_NAME}" up -d

echo "Done. If needed, stop it with: docker compose -p ${IRIS_PROJECT_NAME} down"