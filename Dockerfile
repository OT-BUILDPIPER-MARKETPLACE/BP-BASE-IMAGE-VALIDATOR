FROM alpine:latest

RUN apk add --no-cache bash jq

# Create non-root user
RUN addgroup -g 65522 buildpiper && \
    adduser -D -u 65522 -G buildpiper -h /home/buildpiper buildpiper

# Recreate all directories present in the referenced Dockerfile
RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /bp/workspace \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /usr/local/bin \
    /etc/timezone \
    /opt/python_versions \
    /opt/jdk \
    /opt/maven \
    /app/venv \
    /tmp && \
    chown -R buildpiper:buildpiper \
        /src /bp /opt /usr/local/bin /tmp /app /home/buildpiper

# Copy your scripts and functions
COPY --chown=buildpiper:buildpiper build.sh .
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/

RUN chmod +x build.sh

ENV SLEEP_DURATION=5s
ENV ACTIVITY_SUB_TASK_CODE=REPLACE_IT
ENV VALIDATION_FAILURE_ACTION=WARNING

USER buildpiper

ENTRYPOINT ["./build.sh"]
