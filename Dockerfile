FROM alpine
RUN apk add --no-cache --upgrade bash
RUN apk add jq
COPY build.sh .

ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/


ENV SLEEP_DURATION 5s
ENV ACTIVITY_SUB_TASK_CODE BP_BASE_IMAGE_VALIDATOR
ENV VALIDATION_FAILURE_ACTION WARNING

ENV WHITELIST_IMAGES_NAME "alpine,scratch"

ENTRYPOINT [ "./build.sh" ]