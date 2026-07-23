#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh


CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "I'll do processing at [${CODEBASE_LOCATION}]"
sleep "${SLEEP_DURATION}"

if [ ! -d "${CODEBASE_LOCATION}" ]; then
    logErrorMessage "Codebase location does not exist: ${CODEBASE_LOCATION}"
    TASK_STATUS=$?
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
    exit 0
fi

cd "${CODEBASE_LOCATION}"

if [ "$(ls -A "${CODEBASE_LOCATION}")" ]; then
    logInfoMessage "Directory has content."
else
    logErrorMessage "Directory is empty."
    TASK_STATUS=$?
fi

RAW_PATH=$(getDockerfilePath)

# Clean the returned path
if [[ -n "$RAW_PATH" && "$RAW_PATH" == *:* ]]; then
    FILE="${RAW_PATH%%:*}"   
    DIR="${RAW_PATH#*:}"     
    DOCKERFILE_PATH="${DIR}/${FILE}"
    logInfoMessage "$DOCKERFILE_PATH"
else
    DOCKERFILE_PATH="$RAW_PATH"
    logInfoMessage "$DOCKERFILE_PATH"
fi

result=$(getLineForAString "$DOCKERFILE_PATH" FROM)

logInfoMessage "Got below lines in Dockerfile [${result}]"

# Consider the Dockerfiles with multi-stage builds.
# In this case, the last one is considered as base image.
base_image=$(getBaseImageFromFilteredDockerfile "$result")

logInfoMessage "Base image extracted: $base_image"


if [ -z "$base_image" ]; then
    logErrorMessage "Base image could not be determined."
    TASK_STATUS=1
    exit 1
fi

if [ -z "$WHITELIST_IMAGES_NAME" ]; then
    logErrorMessage "WHITELIST_IMAGES_NAME is empty or not configured."
    TASK_STATUS=1
    exit 1
fi

#WHITELIST_IMAGES_NAME="ubuntu:24.04,alpine:latest,node:20,python:3.12"

if [ -n "$base_image" && -n "$WHITELIST_IMAGES_NAME" ]; then
    logInfoMessage "The base image is: ${base_image}"
    textExistsInALine "$base_image" "${WHITELIST_IMAGES_NAME}"
    if [ $? -eq 0 ]; then
        logInfoMessage "Image is whitelisted: $base_image"
    else
        logErrorMessage "Image is not whitelisted: $base_image"
        TASK_STATUS=1
    fi
fi

if [ "$BASE_IMAGE_HAS_VULNERABILITIES" = "true" ]; then
    if [ -n "$SCAN_SEVERITY" ]; then
        rm -f scout.*

        logInfoMessage "Removing scout.txt and scout.csv"
        logInfoMessage "Scanning for CVEs in base image: $base_image"

        docker scout cves "$base_image" --only-severity "$SCAN_SEVERITY" | tee scout.txt

        echo "Package,Severity,CVE" > scout.csv

        awk '
        /^pkg:/ {pkg=$0}
        /^[[:space:]]*✗/ {
            sev=$2
            cve=$3
            print pkg "," sev "," cve
        }
        ' scout.txt >> scout.csv

    else
        logErrorMessage "SCAN_SEVERITY is not set. Skipping CVE scan."
        TASK_STATUS=1
        exit 1
    fi
else
    logWarningMessage "Skipping CVE scan for base image: $base_image"
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
# # -----------------------------
# # 4. Generate JSON Report
# # -----------------------------
# # Ensure execution dir is set
# EXECUTION_DIR="${EXECUTION_DIR:-/bp/execution_dir}"

# REPORT_PATH="${EXECUTION_DIR}/base_image_validation_report.json"

# cat <<EOF > "${REPORT_PATH}" 2>/dev/null || true
# {
#   "codebase_location": "${CODEBASE_LOCATION}",
#   "task_status": ${TASK_STATUS},
#   "dockerfile_path": "${FULL_DOCKERFILE_PATH}",
#   "base_image": "${BASE_IMAGE}",
#   "message": "$( [ $TASK_STATUS -eq 0 ] && echo "Validation successful" || echo "Validation failed" )",
#   "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
# }
# EOF

# logInfoMessage "Generated JSON report at: ${REPORT_PATH}"

# saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}" 


