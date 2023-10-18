#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/docker-functions.sh

TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION
cd "${CODEBASE_LOCATION}"

DOCKER_FILE_PARENT_PATH=`getDockerfileParentPath`
DOCKER_FILE_NAME=`getDockerfileName`

DOCKERFILE_PATH="${DOCKER_FILE_PARENT_PATH}/${DOCKER_FILE_NAME}"
logInfoMessage "Finding [${WHITELIST_IMAGES_NAME}] text in ${DOCKERFILE_PATH}"
cat ${DOCKERFILE_PATH}
echo ""
result=`getLineForAString ${DOCKERFILE_PATH} FROM`

logInfoMessage "Got below lines in Dockerfile [${result}]"

# Consider the Dockerfiles with multi-stage builds.
# In this case, the last one is considered as base image.
base_image=`getBaseImageFromFilteredDockerfile ${result}`

if [ -n "$base_image" ]; then
    logInfoMessage "The base image is: ${base_image}"
    textExistsInALine "$base_image" "${WHITELIST_IMAGES_NAME}"
    if [ $? -eq 0 ]; then
        logInfoMessage "Image is whitelisted: $base_image"
    else
        logWarningMessage "Image is not whitelisted: $base_image"
        TASK_STATUS=1
    fi
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}