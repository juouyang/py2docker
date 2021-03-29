#!/bin/bash

SOURCE_DIR='.'

if [ ! -f "$SOURCE_DIR/$1" ]; then
	echo "Config: $1 not found"
    exit -1
fi

source $SOURCE_DIR/$1

if [ -z "$PYTHON_VERSION" ]; then echo "Config file error" && exit -1; fi

sudo docker run --rm -it $APP_NAME:$APP_VERSION
#sudo docker run --rm -it --entrypoint /bin/bash $APP_NAME:$APP_VERSION
