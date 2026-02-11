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
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh

ENV ACTIVITY_SUB_TASK_CODE="BP-BASE-IMAGE-VALIDATOR"
ENV SLEEP_DURATION="0s"


USER buildpiper
WORKDIR /home/buildpiper




ENTRYPOINT ["./build.sh"]
