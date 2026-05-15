#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-dry-run}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"
INSTANCE_NAME="${IRIS_INSTANCE_NAME:-IRIS}"
NAMESPACE="${IRIS_NAMESPACE:-USER}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run the POS replay batch" >&2
  exit 1
fi

case "${MODE}" in
  dry-run|apply)
    ;;
  *)
    echo "Usage: $0 [dry-run|apply]" >&2
    exit 1
    ;;
esac

docker exec -i "${CONTAINER_NAME}" bash -lc "/home/irisowner/bin/iris session ${INSTANCE_NAME} -U ${NAMESPACE}" <<EOF
Set sc = ##class(Service.POSReplayBatch).Run("${MODE}")
Write !, "Batch status: ", \$SYSTEM.Status.GetErrorText(sc), !
Halt
EOF