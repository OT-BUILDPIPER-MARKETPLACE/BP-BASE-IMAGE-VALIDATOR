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

logInfoMessage "Finding [${WHITELIST_IMAGE_NAME}] text in Dockerfile"
cat Dockerfile
echo ""
result=`getLineForAString Dockerfile FROM`

logInfoMessage "Got below lines in Dockerfile [${result}]"

TASK_STATUS=`textExistsInALine "$result" "${WHITELIST_IMAGE_NAME}"`

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}