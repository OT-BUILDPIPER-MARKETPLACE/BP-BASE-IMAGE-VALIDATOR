#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/docker-functions.sh


CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [${CODEBASE_LOCATION}]"
sleep "${SLEEP_DURATION}"

if [ -d "reports" ]; then
    true
else
    mkdir reports
fi

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

if [ -n "$base_image" ]; then
    logInfoMessage "The base image is: ${base_image}"
    textExistsInALine "$base_image" "${WHITELIST_IMAGES_NAME}"
    if [ $? -eq 0 ]; then
        logInfoMessage "Image is whitelisted: $base_image"
    else
        logErrorMessage "Image is not whitelisted: $base_image"
        TASK_STATUS=1
        exit 1
    fi
fi

if [ "$BASE_IMAGE_HAS_VULNERABILITIES" = "true" ]; then
    if [ -n "$SCAN_SEVERITY" ]; then
        logInfoMessage "Scanning for CVEs in base image: $base_image"

        docker-scout cves "$base_image" --only-severity "$SCAN_SEVERITY" | tee scout.txt

        echo "Package,Severity,CVE" > reports/scout.csv

        awk '
        /^pkg:/ {pkg=$0}
        /^[[:space:]]*✗/ {
            sev=$2
            cve=$3
            print pkg "," sev "," cve
        }
        ' scout.txt >> reports/scout.csv

        if [ -n "${GLOBAL_TASK_ID}" ]; then
            cp -rf reports/* "/bp/execution_dir/${GLOBAL_TASK_ID}/"
            logInfoMessage "Copied reports to /bp/execution_dir/${GLOBAL_TASK_ID}/"
        else
            logWarningMessage "GLOBAL_TASK_ID not set; skipping UI copy"
        fi

    else
        logErrorMessage "SCAN_SEVERITY is not set. Skipping CVE scan."
        TASK_STATUS=1
        exit 1
    fi
else
    logWarningMessage "Skipping CVE scan for base image: $base_image"
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
