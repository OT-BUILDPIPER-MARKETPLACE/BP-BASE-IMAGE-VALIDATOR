#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh

TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION
cd "${CODEBASE_LOCATION}"

TASK_STATUS=0
DOCKER_FILE_PARENT_PATH=`getDockerfileParentPath`
DOCKER_FILE_NAME=`getDockerfileName`

DOCKERFILE_PATH="${DOCKER_FILE_PARENT_PATH}/${DOCKER_FILE_NAME}"
logInfoMessage "Finding [${WHITELIST_IMAGE_NAME}] text in ${DOCKERFILE_PATH}"
cat ${DOCKERFILE_PATH}
echo ""
result=`getLineForAString ${DOCKERFILE_PATH} FROM`

logInfoMessage "Got below lines in Dockerfile [${result}]"

TASK_STATUS=`textExistsInALine "$result" "${WHITELIST_IMAGE_NAME}"`

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}