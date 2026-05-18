#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"
INSTANCE_NAME="${IRIS_INSTANCE_NAME:-IRIS}"
NAMESPACE="${IRIS_NAMESPACE:-USER}"
PYTHON_BIN="${PYTHON_BIN:-${WORKSPACE_DIR}/.venv/bin/python}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to load mock data into IRIS" >&2
  exit 1
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "Python interpreter not found at ${PYTHON_BIN}" >&2
  exit 1
fi

"${PYTHON_BIN}" "${WORKSPACE_DIR}/scripts/generate_may_2026_mock_data.py"

docker exec -i "${CONTAINER_NAME}" bash -lc "/home/irisowner/bin/iris session ${INSTANCE_NAME} -U ${NAMESPACE}" <<EOF
Set sc = ##class(Service.MockDataImportService).ImportMay2026MockMonth("/iris/data")
Write !, "Mock month load status: ", \$SYSTEM.Status.GetErrorText(sc), !
Halt
EOF

echo "Mock May 2026 data loaded into IRIS from ${WORKSPACE_DIR}/data"