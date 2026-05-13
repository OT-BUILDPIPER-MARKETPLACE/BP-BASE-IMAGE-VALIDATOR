#!/bin/bash
set -euo pipefail

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

###############################################
### DEBUG
###############################################
if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

###############################################
### VARIABLES
###############################################
STATUS=0

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

REPORTS_DIR="${CODEBASE_LOCATION}/reports"

mkdir -p "${REPORTS_DIR}"

chmod -R 777 "${REPORTS_DIR}" 2>/dev/null || true

###############################################
### EXECUTION DIRECTORY
###############################################
if [[ -z "${GLOBAL_TASK_ID:-}" ]]; then
    echo "[ERROR] GLOBAL_TASK_ID not set"
    logErrorMessage "GLOBAL_TASK_ID not set"
    exit 1
fi

EXEC_DIR="/bp/execution_dir/${GLOBAL_TASK_ID}"

mkdir -p "${EXEC_DIR}"

chmod -R 777 "${EXEC_DIR}" 2>/dev/null || true

###############################################
### OUTPUT FILE
###############################################
SAFE_TASK_CODE=$(echo "${ACTIVITY_SUB_TASK_CODE}" | tr ' ' '_' | tr '/' '_')

OUTPUT_FILE="${SAFE_TASK_CODE}_output.json"

###############################################
### REPORT FILES
###############################################
REPORT_PATH="${REPORTS_DIR}/base_image_validation_report.json"

CSV_REPORT="${REPORTS_DIR}/base_image_validation_report.csv"

###############################################
### EVENTS TRACKING
###############################################
EVENTS='{}'

add_event() {
  local key="${1:-}"
  local status="${2:-}"
  local reason="${3:-}"
  local message="${4:-}"

  if [[ -z "$key" || -z "$status" ]]; then
    echo "Error: add_event requires key and status" >&2
    return 1
  fi

  key="$(echo "$key" | tr '_' ' ' | tr '-' ' ' | tr '[:upper:]' '[:lower:]')"

  EVENTS=$(jq \
    --arg k "$key" \
    --arg status "$status" \
    --arg reason "$reason" \
    --arg message "$message" \
    '. + {($k): {status: $status, reason: $reason, message: $message}}' \
    <<< "$EVENTS")
}

###############################################
### INITIALIZATION
###############################################
echo "========================================="
echo "Starting Base Image Validation"
echo "========================================="

logInfoMessage "========================================="
logInfoMessage "Starting Base Image Validation"
logInfoMessage "========================================="

logInfoMessage "Processing at [${CODEBASE_LOCATION}]"

sleep "${SLEEP_DURATION:-0}"

add_event "initialization" "Successful" \
"Task initialization completed" \
"Processing at: ${CODEBASE_LOCATION}"

###############################################
### CODEBASE VALIDATION
###############################################
if [[ ! -d "${CODEBASE_LOCATION}" ]]; then

    echo "========================================="
    echo "[ERROR] Codebase Validation Failed"
    echo "[ERROR] Codebase location does not exist"
    echo "[ERROR] Path: ${CODEBASE_LOCATION}"
    echo "========================================="

    logErrorMessage "Codebase Validation Failed"
    logErrorMessage "Codebase location does not exist"
    logErrorMessage "Path: ${CODEBASE_LOCATION}"

    add_event "codebase validation" "Failed" \
    "Codebase location not found" \
    "Path: ${CODEBASE_LOCATION}"

    STATUS=1

else

    echo "[INFO] Codebase location verified"

    logInfoMessage "Codebase location verified"

    add_event "codebase validation" "Successful" \
    "Codebase location verified" \
    "Path: ${CODEBASE_LOCATION}"
fi

###############################################
### CHANGE DIRECTORY
###############################################
if ! cd "${CODEBASE_LOCATION}" 2>/dev/null; then

    echo "========================================="
    echo "[ERROR] Directory Change Failed"
    echo "[ERROR] Unable to access codebase directory"
    echo "[ERROR] Path: ${CODEBASE_LOCATION}"
    echo "========================================="

    logErrorMessage "Directory Change Failed"
    logErrorMessage "Unable to access codebase directory"
    logErrorMessage "Path: ${CODEBASE_LOCATION}"

    add_event "directory change" "Failed" \
    "Unable to change directory" \
    "Path: ${CODEBASE_LOCATION}"

    STATUS=1
fi

###############################################
### DIRECTORY VALIDATION
###############################################
if [[ "$(ls -A "${CODEBASE_LOCATION}" 2>/dev/null)" ]]; then

    echo "[INFO] Directory has content"

    logInfoMessage "Directory has content"

    add_event "directory check" "Successful" \
    "Directory is not empty" \
    "Ready for validation"

else

    echo "========================================="
    echo "[ERROR] Directory Validation Failed"
    echo "[ERROR] Directory is empty"
    echo "[ERROR] No files available for validation"
    echo "========================================="

    logErrorMessage "Directory Validation Failed"
    logErrorMessage "Directory is empty"
    logErrorMessage "No files available for validation"

    add_event "directory check" "Failed" \
    "Directory is empty" \
    "No files available for validation"

    STATUS=1
fi

###############################################
### GET DOCKERFILE PATH
###############################################
RAW_PATH=$(getDockerfilePath || true)

DOCKERFILE_PATH=$(echo "${RAW_PATH}" | sed 's/:.$//' | sed 's/:$//')

if [[ -z "${DOCKERFILE_PATH}" || "${DOCKERFILE_PATH}" == "null" ]]; then

    echo "[WARN] Dockerfile path missing. Auto-searching..."

    logWarningMessage "Dockerfile path missing. Auto-searching..."

    DOCKERFILE_PATH=$(find . -maxdepth 5 -type f -iname "Dockerfile" | head -1 || true)

    if [[ -z "${DOCKERFILE_PATH}" ]]; then

        echo "========================================="
        echo "[ERROR] Dockerfile Search Failed"
        echo "[ERROR] No Dockerfile found"
        echo "[ERROR] Searched up to 5 levels deep"
        echo "========================================="

        logErrorMessage "Dockerfile Search Failed"
        logErrorMessage "No Dockerfile found"
        logErrorMessage "Searched up to 5 levels deep"

        add_event "dockerfile search" "Failed" \
        "No Dockerfile found in codebase" \
        "Searched up to 5 levels deep"

        STATUS=1

    else

        echo "[INFO] Dockerfile auto-found at: ${DOCKERFILE_PATH}"

        logInfoMessage "Dockerfile auto-found at: ${DOCKERFILE_PATH}"

        add_event "dockerfile search" "Successful" \
        "Dockerfile found via auto-search" \
        "Path: ${DOCKERFILE_PATH}"
    fi

else

    echo "[INFO] Dockerfile path retrieved: ${DOCKERFILE_PATH}"

    logInfoMessage "Dockerfile path retrieved: ${DOCKERFILE_PATH}"

    add_event "dockerfile search" "Successful" \
    "Dockerfile path retrieved" \
    "Path: ${DOCKERFILE_PATH}"
fi

###############################################
### NORMALIZE DOCKERFILE PATH
###############################################
DOCKERFILE_PATH="${DOCKERFILE_PATH#./}"

FULL_DOCKERFILE_PATH="${CODEBASE_LOCATION}/${DOCKERFILE_PATH}"

###############################################
### BASE IMAGE VALIDATION
###############################################
BASE_IMAGE=""

if [[ -f "${FULL_DOCKERFILE_PATH}" ]]; then

    BASE_IMAGE=$(grep -E '^FROM ' "${FULL_DOCKERFILE_PATH}" | head -1 | awk '{print $2}' || true)

    if [[ -n "${BASE_IMAGE}" ]]; then

        echo "[INFO] Base image found: ${BASE_IMAGE}"

        logInfoMessage "Base image found: ${BASE_IMAGE}"

        add_event "base image validation" "Successful" \
        "Base image identified" \
        "Base Image: ${BASE_IMAGE}"

    else

        echo "========================================="
        echo "[ERROR] Base Image Validation Failed"
        echo "[ERROR] No FROM instruction found"
        echo "[ERROR] File: ${FULL_DOCKERFILE_PATH}"
        echo "========================================="

        logErrorMessage "Base Image Validation Failed"
        logErrorMessage "No FROM instruction found"
        logErrorMessage "File: ${FULL_DOCKERFILE_PATH}"

        add_event "base image validation" "Failed" \
        "No FROM instruction found" \
        "File: ${FULL_DOCKERFILE_PATH}"

        STATUS=1
    fi

else

    echo "========================================="
    echo "[ERROR] Dockerfile Validation Failed"
    echo "[ERROR] Dockerfile not found"
    echo "[ERROR] Expected Path: ${FULL_DOCKERFILE_PATH}"
    echo "========================================="

    logErrorMessage "Dockerfile Validation Failed"
    logErrorMessage "Dockerfile not found"
    logErrorMessage "Expected Path: ${FULL_DOCKERFILE_PATH}"

    add_event "base image validation" "Failed" \
    "Dockerfile not found" \
    "Expected: ${FULL_DOCKERFILE_PATH}"

    STATUS=1
fi

###############################################
### FINAL MESSAGE
###############################################
FINAL_MESSAGE="DOCKERFILE=${DOCKERFILE_PATH:-NOT_FOUND} BASE_IMAGE=${BASE_IMAGE:-NOT_FOUND}"

###############################################
### ERROR EVENTS
###############################################
ERROR_EVENTS=$(echo "$EVENTS" | jq '[to_entries[] | select(.value.status == "Failed") | .key]')

###############################################
### GENERATE JSON REPORT
###############################################
jq -n \
  --arg codebase "${CODEBASE_LOCATION}" \
  --arg dockerfile "${FULL_DOCKERFILE_PATH}" \
  --arg base_image "${BASE_IMAGE}" \
  --arg message "${FINAL_MESSAGE}" \
  --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
  --argjson status "${STATUS}" \
'{
  codebase_location: $codebase,
  task_status: $status,
  dockerfile_path: $dockerfile,
  base_image: $base_image,
  message: $message,
  timestamp: $timestamp
}' > "${REPORT_PATH}"

chmod 777 "${REPORT_PATH}" 2>/dev/null || true

echo "[INFO] JSON report generated at: ${REPORT_PATH}"

logInfoMessage "Generated JSON report at: ${REPORT_PATH}"

###############################################
### GENERATE CSV REPORT
###############################################
echo "timestamp,codebase_location,dockerfile_path,base_image,status,message" > "${CSV_REPORT}"

echo "\"$(date +"%Y-%m-%d %H:%M:%S")\",\"${CODEBASE_LOCATION}\",\"${FULL_DOCKERFILE_PATH}\",\"${BASE_IMAGE:-NOT_FOUND}\",\"${STATUS}\",\"${FINAL_MESSAGE}\"" \
>> "${CSV_REPORT}"

chmod 777 "${CSV_REPORT}" 2>/dev/null || true

echo "[INFO] CSV report generated at: ${CSV_REPORT}"

logInfoMessage "Generated CSV report at: ${CSV_REPORT}"

###############################################
### COPY REPORTS TO EXECUTION DIRECTORY
###############################################
echo "[INFO] Copying reports to execution directory"

logInfoMessage "Copying reports to execution directory"

cp -f "${REPORT_PATH}" "${EXEC_DIR}/" 2>/dev/null || true
cp -f "${CSV_REPORT}" "${EXEC_DIR}/" 2>/dev/null || true

chmod -R 777 "${EXEC_DIR}" 2>/dev/null || true

add_event "copy reports" "Successful" \
"Reports copied" \
"Copied reports to ${EXEC_DIR}"

###############################################
### OUTPUT JSON
###############################################
jq -n \
  --argjson events "$EVENTS" \
  --argjson error_events "$ERROR_EVENTS" \
  --arg message "$FINAL_MESSAGE" \
  --arg status "$STATUS" \
  --arg dockerfile "${DOCKERFILE_PATH:-}" \
  --arg base_image "${BASE_IMAGE:-}" \
'{
  build: {
    status: ($status|tonumber == 0),
    message: $message,
    events: $events,
    error_events: $error_events
  },
  output_vars: {
    base_image_validation: {
      status: (if ($status|tonumber == 0) then "Successful" else "Failed" end),
      message: $message,
      dockerfile_path: $dockerfile,
      base_image: $base_image
    }
  }
}' > "${EXEC_DIR}/${OUTPUT_FILE}"

chmod 777 "${EXEC_DIR}/${OUTPUT_FILE}" 2>/dev/null || true

echo "[INFO] Output written -> ${EXEC_DIR}/${OUTPUT_FILE}"

logInfoMessage "Output written -> ${EXEC_DIR}/${OUTPUT_FILE}"

###############################################
### FINAL SUMMARY
###############################################
echo "========================================="
echo "Base Image Validation Summary"
echo "${FINAL_MESSAGE}"
echo "========================================="

logInfoMessage "========================================="
logInfoMessage "Base Image Validation Summary"
logInfoMessage "========================================="
logInfoMessage "${FINAL_MESSAGE}"

###############################################
### PIPELINE STATUS
###############################################
if [[ "${STATUS}" -eq 0 ]]; then

    echo "[INFO] Base image validation completed successfully"

    logInfoMessage "Base image validation completed successfully"

    generateOutput "${ACTIVITY_SUB_TASK_CODE}" true \
    "${FINAL_MESSAGE}"

else

    echo "[ERROR] Base image validation failed"

    logErrorMessage "Base image validation failed"

    generateOutput "${ACTIVITY_SUB_TASK_CODE}" false \
    "${FINAL_MESSAGE}"
fi

saveTaskStatus "${STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
