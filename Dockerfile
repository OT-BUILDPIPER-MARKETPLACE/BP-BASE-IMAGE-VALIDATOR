FROM alpine:3.19

RUN apk add --no-cache bash jq git

# Create non-root user
RUN addgroup -g 65522 buildpiper && \
    adduser -D -u 65522 -G buildpiper -h /home/buildpiper buildpiper

# Create required directories
RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /bp/workspace \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /usr/local/bin \
    /tmp && \
    chown -R buildpiper:buildpiper \
        /src /bp /opt /usr/local/bin /tmp /home/buildpiper

# Copy your scripts and functions
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh

# Clone shell functions directly (avoids submodule init dependency in CI)
RUN git clone --branch nr_0.5.1 --depth 1 \
    https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-BASE-SHELL-STEPS.git \
    /opt/buildpiper/shell-functions && \
    chown -R buildpiper:buildpiper /opt/buildpiper/shell-functions

RUN chmod +x /home/buildpiper/build.sh

ENV ACTIVITY_SUB_TASK_CODE="BP-BASE-IMAGE-VALIDATOR"
ENV SLEEP_DURATION="0s"


USER buildpiper
WORKDIR /home/buildpiper




ENTRYPOINT ["./build.sh"]
