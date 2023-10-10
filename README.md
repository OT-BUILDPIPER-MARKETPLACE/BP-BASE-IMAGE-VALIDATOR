# BP-SHELL-STEP-TEMPLATE
I'll <do xyz>

## Setup
* Clone the code available at [BP-BASE-IMAGE-VALIDATOR
](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-BASE-IMAGE-VALIDATOR)

* Build the docker image
```
git submodule init
git submodule update
docker build -t ot/bp-base-image-validator:0.1 .
```

* Do local testing
```
Successful scenario
docker run -it --rm -v $PWD:/src -e WORKSPACE=/ -e CODEBASE_DIR=src ot/bp-base-image-validator:0.1

Failure scenario
docker run -it --rm -v $PWD:/src -e WHITELIST_IMAGE_NAME=alpn  -e WORKSPACE=/ -e CODEBASE_DIR=src ot/bp-base-image-validator:0.1

```

* Debug
```
docker run -it --rm -v $PWD:/src -e SLEEP_DURATION=10m -e WORKSPACE=/ -e CODEBASE_DIR=src ot/bp-base-image-validator:0.1
```