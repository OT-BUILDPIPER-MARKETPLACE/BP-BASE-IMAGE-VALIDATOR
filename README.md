# BP-SHELL-STEP-TEMPLATE
I'll <do xyz>

## Setup
* Clone the code available at [BP-BASE-IMAGE-VALIDATOR
](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-BASE-IMAGE-VALIDATOR)

* Build the docker image
```
git submodule init
git submodule update
docker build -t ot/bp-base-image-validator:0.1:0.1 .
```

* Do local testing
```
docker run -it --rm -v $PWD:/src -e var1="key1" -e var2="key2" ot/<image-name>:0.1
```

* Debug
```
docker run -it --rm -v $PWD:/src -e var1="key1" -e var2="key2" --entrypoint sh ot/<image-name>:0.1
```