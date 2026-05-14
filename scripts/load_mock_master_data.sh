#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"
INSTANCE_NAME="${IRIS_INSTANCE_NAME:-IRIS}"
NAMESPACE="${IRIS_NAMESPACE:-USER}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to load mock master data into IRIS" >&2
  exit 1
fi

docker exec -i "${CONTAINER_NAME}" bash -lc "/home/irisowner/bin/iris session ${INSTANCE_NAME} -U ${NAMESPACE}" <<EOF
Set sc = ##class(Service.MockDataImportService).ImportAll("/iris/data")
Write !, "Load status: ", \$SYSTEM.Status.GetErrorText(sc), !
Halt
EOF

echo "Mock master data load finished from ${WORKSPACE_DIR}/data"