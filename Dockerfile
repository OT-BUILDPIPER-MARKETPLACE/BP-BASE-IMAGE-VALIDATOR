FROM docker:28-cli

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    grep \
    gawk \
    coreutils \
    tar


RUN addgroup -g 65522 buildpiper && \
    adduser -D -u 65522 -G buildpiper -h /home/buildpiper buildpiper


RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /bp/workspace \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /usr/local/bin \
    /opt/python_versions \
    /opt/jdk \
    /opt/maven \
    /app/venv \
    /tmp \
    /home/buildpiper/.docker/scout && \
    chown -R buildpiper:buildpiper \
        /src \
        /bp \
        /opt \
        /usr/local/bin \
        /tmp \
        /app \
        /home/buildpiper

USER buildpiper

ENV DOCKER_SCOUT_INSTALL_DIR=/opt/docker-scout

RUN mkdir -p ${DOCKER_SCOUT_INSTALL_DIR} && \
    curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | \
    sh -s -- -b ${DOCKER_SCOUT_INSTALL_DIR}

ENV PATH="${DOCKER_SCOUT_INSTALL_DIR}:${PATH}"


RUN docker-scout version

COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh

ENV HOME=/home/buildpiper
ENV ACTIVITY_SUB_TASK_CODE=BP-BASE-IMAGE-VALIDATOR
ENV SLEEP_DURATION=0s

WORKDIR /home/buildpiper

ENTRYPOINT ["./build.sh"]
