#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "I'll do processing at [${CODEBASE_LOCATION}]"
sleep "${SLEEP_DURATION}"

if [ ! -d "${CODEBASE_LOCATION}" ]; then
    logErrorMessage "Codebase location does not exist: ${CODEBASE_LOCATION}"
    TASK_STATUS=1
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
    exit 0
fi

cd "${CODEBASE_LOCATION}"

# -----------------------------
# 1. Check directory is not empty
# -----------------------------
if [ "$(ls -A "${CODEBASE_LOCATION}")" ]; then
    logInfoMessage "Directory has content."
else
    logErrorMessage "Directory is empty."
    TASK_STATUS=1
fi

# -----------------------------
# 2. Get Dockerfile path
# -----------------------------
RAW_PATH=$(getDockerfilePath)

# Clean the returned path
DOCKERFILE_PATH=$(echo "$RAW_PATH" | sed 's/:.$//' | sed 's/:$//')

if [ -z "${DOCKERFILE_PATH}" ] || [ "${DOCKERFILE_PATH}" == "null" ]; then
    logWarningMessage "Dockerfile path missing in JSON. Auto-searching..."

    DOCKERFILE_PATH=$(find . -maxdepth 5 -type f -iname "Dockerfile" | head -1)

    if [ -z "${DOCKERFILE_PATH}" ]; then
        logErrorMessage "Auto-search failed. No Dockerfile found."
        TASK_STATUS=1
    else
        logInfoMessage "Dockerfile auto-found at: ${DOCKERFILE_PATH}"
    fi
else
    logInfoMessage "Dockerfile path retrieved: ${DOCKERFILE_PATH}"
fi

# Remove leading ./ if exists
DOCKERFILE_PATH="${DOCKERFILE_PATH#./}"

# Build full path
FULL_DOCKERFILE_PATH="${CODEBASE_LOCATION}/${DOCKERFILE_PATH}"

# -----------------------------
# 3. Validate Base Image
# -----------------------------
if [ -f "${FULL_DOCKERFILE_PATH}" ]; then
    BASE_IMAGE=$(grep -E '^FROM ' "${FULL_DOCKERFILE_PATH}" | head -1 | awk '{print $2}')

    if [ -n "${BASE_IMAGE}" ]; then
        logInfoMessage "Base image found: ${BASE_IMAGE}"
    else
        logErrorMessage "No valid FROM instruction found in Dockerfile."
        TASK_STATUS=1
    fi
else
    logErrorMessage "Dockerfile not found at: ${FULL_DOCKERFILEFILE_PATH}"
    TASK_STATUS=1
fi

# -----------------------------
# 4. Generate JSON Report
# -----------------------------
# Ensure execution dir is set
EXECUTION_DIR="${EXECUTION_DIR:-/bp/execution_dir}"

REPORT_PATH="${EXECUTION_DIR}/base_image_validation_report.json"

cat <<EOF > "${REPORT_PATH}" 2>/dev/null || true
{
  "codebase_location": "${CODEBASE_LOCATION}",
  "task_status": ${TASK_STATUS},
  "dockerfile_path": "${FULL_DOCKERFILE_PATH}",
  "base_image": "${BASE_IMAGE}",
  "message": "$( [ $TASK_STATUS -eq 0 ] && echo "Validation successful" || echo "Validation failed" )",
  "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF

logInfoMessage "Generated JSON report at: ${REPORT_PATH}"

saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}" 2>/dev/null || true
exit 0

