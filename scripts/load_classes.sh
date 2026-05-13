#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"
INSTANCE_NAME="${IRIS_INSTANCE_NAME:-IRIS}"
NAMESPACE="${IRIS_NAMESPACE:-USER}"
CONTAINER_SRC_ROOT="${IRIS_CONTAINER_SRC_ROOT:-/iris/code}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to load classes into IRIS" >&2
  exit 1
fi

class_count=0

while IFS= read -r class_file; do
  class_count=$((class_count + 1))
  container_class_file="${class_file/${WORKSPACE_DIR}\/src/${CONTAINER_SRC_ROOT}}"
  echo "Compiling ${class_file}"
  docker exec -i "${CONTAINER_NAME}" bash -lc "/home/irisowner/bin/iris session ${INSTANCE_NAME} -U ${NAMESPACE}" <<EOF
Set sc = \$SYSTEM.OBJ.Load("${container_class_file}", "ck")
Write !, "Compile status: ", \$SYSTEM.Status.GetErrorText(sc), !
Halt
EOF
done < <(find "${WORKSPACE_DIR}/src" -name '*.cls' | sort)

if [[ ${class_count} -eq 0 ]]; then
  echo "No class files found under ${WORKSPACE_DIR}/src" >&2
  exit 1
fi

echo "Class compilation finished for ${class_count} file(s)."
