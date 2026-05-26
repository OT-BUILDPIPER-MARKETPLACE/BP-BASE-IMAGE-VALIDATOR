#!/bin/bash

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

if [ "$DEBUG" = true ]; then
    set -x
fi

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/bp/workspace}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
EXECUTION_DIR="${EXECUTION_DIR:-/bp/execution_dir}"
TASK_STATUS=0

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: base_image_validator"
logInfoMessage "> Codebase location: ${CODEBASE_LOCATION}"

add_event "INITIALIZATION" "Successful" \
    "Base Image Validator step initialized" \
    "Codebase: ${CODEBASE_DIR} | Workspace: ${WORKSPACE}"

if [ -n "$SLEEP_DURATION" ] && [ "$SLEEP_DURATION" -gt 0 ] 2>/dev/null; then
    logInfoMessage "> Sleeping for ${SLEEP_DURATION} second(s)..."
    sleep "$SLEEP_DURATION"
fi

# ---------------------------------------------------------------
# 2. Input Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating inputs..."

if [ -z "$WORKSPACE" ] || [ -z "$CODEBASE_DIR" ]; then
    logErrorMessage "> WORKSPACE or CODEBASE_DIR is not set — cannot proceed"
    add_event "INPUT_VALIDATION" "Failed" \
        "Required environment variables are missing" \
        "WORKSPACE: ${WORKSPACE:-<unset>} | CODEBASE_DIR: ${CODEBASE_DIR:-<unset>}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

add_event "INPUT_VALIDATION" "Successful" \
    "Required environment variables validated" \
    "WORKSPACE: ${WORKSPACE} | CODEBASE_DIR: ${CODEBASE_DIR}"

# ---------------------------------------------------------------
# 3. Execution Summary
# ---------------------------------------------------------------
echo ""
echo "> Base Image Validator Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase" "${CODEBASE_DIR}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase Path" "${CODEBASE_LOCATION}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Report Output" "${EXECUTION_DIR}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

# ---------------------------------------------------------------
# 4. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Validating codebase directory..."

if [ ! -d "${CODEBASE_LOCATION}" ]; then
    logErrorMessage "> Codebase directory does not exist: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Codebase directory not found" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

if [ -z "$(ls -A "${CODEBASE_LOCATION}")" ]; then
    logErrorMessage "> Codebase directory is empty: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Codebase directory is empty — no files to validate" \
        "Path: ${CODEBASE_LOCATION}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Cannot change to codebase directory" \
        "Path: ${CODEBASE_LOCATION}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

logInfoMessage "> Codebase directory validated and navigated: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Codebase directory validated and accessed" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 5. Dockerfile Discovery
# ---------------------------------------------------------------
logInfoMessage "> Resolving Dockerfile path..."

RAW_PATH=$(getDockerfilePath)

# getDockerfilePath returns 'DockerfileName:DirectoryName' (e.g. 'Dockerfile:emp_backend')
# Parse name and directory, then reconstruct as 'dir/name'
DOCKERFILE_NAME=$(echo "$RAW_PATH" | cut -d':' -f1)
DOCKERFILE_DIR=$(echo "$RAW_PATH"  | cut -d':' -f2)

if [ -n "$DOCKERFILE_DIR" ] && [ "$DOCKERFILE_DIR" != "$DOCKERFILE_NAME" ]; then
    DOCKERFILE_PATH="${DOCKERFILE_DIR}/${DOCKERFILE_NAME}"
else
    DOCKERFILE_PATH="${DOCKERFILE_NAME}"
fi

if [ -z "${DOCKERFILE_PATH}" ] || [ "${DOCKERFILE_PATH}" == "null" ]; then
    logInfoMessage "> Dockerfile path not found in build metadata — running auto-search..."

    DOCKERFILE_PATH=$(find . -maxdepth 5 -type f -iname "Dockerfile" | head -1)

    if [ -z "${DOCKERFILE_PATH}" ]; then
        logErrorMessage "> Auto-search failed — no Dockerfile found within 5 directory levels"
        add_event "DOCKERFILE_DISCOVERY" "Failed" \
            "No Dockerfile found in codebase" \
            "Searched: ${CODEBASE_LOCATION} (maxdepth: 5)"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    fi

    logInfoMessage "> Dockerfile found via auto-search: ${DOCKERFILE_PATH}"
    add_event "DOCKERFILE_DISCOVERY" "Successful" \
        "Dockerfile found via auto-search" \
        "Path: ${DOCKERFILE_PATH}"
else
    logInfoMessage "> Dockerfile path retrieved from build metadata: ${DOCKERFILE_PATH}"
    add_event "DOCKERFILE_DISCOVERY" "Successful" \
        "Dockerfile path retrieved from build details" \
        "Path: ${DOCKERFILE_PATH}"
fi

# Strip leading ./
DOCKERFILE_PATH="${DOCKERFILE_PATH#./}"
FULL_DOCKERFILE_PATH="${CODEBASE_LOCATION}/${DOCKERFILE_PATH}"

logInfoMessage "> Full Dockerfile path: ${FULL_DOCKERFILE_PATH}"

# ---------------------------------------------------------------
# 6. Base Image Validation
# ---------------------------------------------------------------
logInfoMessage "> Extracting base image from Dockerfile..."

if [ ! -f "${FULL_DOCKERFILE_PATH}" ]; then
    logErrorMessage "> Dockerfile not found at: ${FULL_DOCKERFILE_PATH}"
    add_event "BASE_IMAGE_VALIDATION" "Failed" \
        "Dockerfile not found at resolved path" \
        "Expected: ${FULL_DOCKERFILE_PATH}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

BASE_IMAGE=$(grep -E '^FROM ' "${FULL_DOCKERFILE_PATH}" | head -1 | awk '{print $2}')

if [ -z "${BASE_IMAGE}" ]; then
    logErrorMessage "> No valid FROM instruction found in Dockerfile: ${FULL_DOCKERFILE_PATH}"
    add_event "BASE_IMAGE_VALIDATION" "Failed" \
        "No FROM instruction found in Dockerfile" \
        "File: ${FULL_DOCKERFILE_PATH}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Base image identified: ${BASE_IMAGE}"
add_event "BASE_IMAGE_VALIDATION" "Successful" \
    "Base image extracted from Dockerfile" \
    "Base Image: ${BASE_IMAGE} | Dockerfile: ${DOCKERFILE_PATH}"

# ---------------------------------------------------------------
# 7. Report Generation
# ---------------------------------------------------------------
logInfoMessage "> Generating validation report..."

REPORT_PATH="${EXECUTION_DIR}/base_image_validation_report.json"
mkdir -p "${EXECUTION_DIR}"

cat > "${REPORT_PATH}" <<EOF
{
  "codebase_location": "${CODEBASE_LOCATION}",
  "task_status": ${TASK_STATUS},
  "dockerfile_path": "${FULL_DOCKERFILE_PATH}",
  "base_image": "${BASE_IMAGE}",
  "message": "Validation successful",
  "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF

logInfoMessage "> Validation report written to: ${REPORT_PATH}"
add_event "REPORT_GENERATION" "Successful" \
    "Validation report generated" \
    "Report: ${REPORT_PATH} | Base Image: ${BASE_IMAGE}"

# ---------------------------------------------------------------
# 8. Final Status
# ---------------------------------------------------------------
logInfoMessage "> Base Image Validator step completed successfully"
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
exit 0
