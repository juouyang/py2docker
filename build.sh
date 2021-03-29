#!/bin/bash

SOURCE_DIR='.'

build () {
if [ ! -f "$SOURCE_DIR/$1" ]; then
	echo "Config: $1 not found"
    exit -1
fi

source $SOURCE_DIR/$1

if [ -z "$PYTHON_VERSION" ]; then echo "Config file error" && exit -1; fi

if [ ! -f "$SOURCE_DIR/$APP_ENTRYPOINT" ]; then echo "Entrypoint: $SOURCE_DIR/$APP_ENTRYPOINT not found" && exit -1; fi

if [ -z "$JENKINS_HOME" ]
then
    ### Manually
    cd $SOURCE_DIR
else
    ### JENKINS
    # APP_VERSION='revision_'$SVN_REVISION
    cd $WORKSPACE
fi

if [ ! -x "$(command -v docker)" ]; then echo "Access https://docs.docker.com/engine/install/, and install docker first." && exit -1; fi

POSTFIX=$RANDOM
if [ -f ".dockerignore" ]; then mv -f .dockerignore .dockerignore.bak; fi
 cat <<EOF > .dockerignore
**/.svn
**/branches
**/tags
**/trunk
**/prop-base
**/props
**/text-base
**/tmp
all-wcprops
entries
format
.gitattributes
**/.git
**/.DS_Store
**/node_modules
*.log
Dockerfile*
docker-compose*
.dockerignore
.git
.gitignore
.vscode
EOF

cat <<EOF > Dockerfile.$POSTFIX
FROM python:$PYTHON_VERSION-slim
USER root
COPY $SOURCE_DIR/py2docker/requirements.txt /tmp
RUN apt-get update \
 && apt-get upgrade -yq --no-install-recommends ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && pip install -r /tmp/requirements.txt \
 && mkdir -p /builds/app
COPY $SOURCE_DIR/ /builds/app/
WORKDIR /builds/app
ENTRYPOINT ["python", "$APP_ENTRYPOINT"]
EOF

sudo docker build -t $APP_NAME:$APP_VERSION --file ./Dockerfile.$POSTFIX .
rm -rf Dockerfile.$POSTFIX
rm -rf .dockerignore
if [ -f ".dockerignore.bak" ]; then mv -f .dockerignore.bak .dockerignore; fi
}

for conf in "./py2docker/*"
do
    build $conf
done
