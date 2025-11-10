#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "I'll do processing at [${CODEBASE_LOCATION}]"
sleep "${SLEEP_DURATION}"

if [ ! -d "${CODEBASE_LOCATION}" ]; then
    logErrorMessage "Codebase location does not exist: ${CODEBASE_LOCATION}"
    TASK_STATUS=1
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

cd "${CODEBASE_LOCATION}"

if [ "$(ls -A "${CODEBASE_LOCATION}")" ]; then
    logInfoMessage "Validation successful. Directory has content."
else
    logErrorMessage "Validation failed. Directory is empty."
    TASK_STATUS=1
fi


REPORT_PATH="/bp/workspace/${CODEBASE_DIR}/base_image_validation_report.json"

cat > "${REPORT_PATH}" <<EOF
{
  "codebase_location": "${CODEBASE_LOCATION}",
  "task_status": ${TASK_STATUS},
  "message": "$( [ $TASK_STATUS -eq 0 ] && echo "Validation successful" || echo "Validation failed" )",
  "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF

logInfoMessage "Generated JSON report at: ${REPORT_PATH}"

saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"

exit "${TASK_STATUS}"
