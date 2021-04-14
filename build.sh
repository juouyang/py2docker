#!/bin/bash

PYTHON_VERSION='3.8'
APP_NAME=$(ls -A1 *.py | grep -v __main__ | sed -e 's/\.py$//')
APP_VERSION='next'
APP_ENTRYPOINT="__main__.py"
SOURCE_DIR='.'

if [ -z "$JENKINS_HOME" ]
then
    ### Manually
    cd $SOURCE_DIR
else
    ### JENKINS
    APP_VERSION="r_$SVN_REVISION"
    cd $WORKSPACE
fi

APP_NAME="${APP_NAME,,}"
APP_NAME="${APP_NAME// /_}"
APP_VERSION="${APP_VERSION,,}"

if [ ! -f "$SOURCE_DIR/$APP_ENTRYPOINT" ]; then echo "Entrypoint: $SOURCE_DIR/$APP_ENTRYPOINT not found" && return 3; fi
if [ ! -x "$(command -v docker)" ]; then echo "Access https://docs.docker.com/engine/install/, and install docker first." && return 4; fi

POSTFIX=$RANDOM
if [ -f ".dockerignore" ]; then mv -f .dockerignore .dockerignore.$POSTFIX.bak; fi
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

TZ=$(cat /etc/timezone 2>/dev/null)
TZ="${TZ:=Asia/Taipei}"

cat <<EOF > requirements.$POSTFIX.txt
schedule==1.0.0
lineTool==1.0.3
pandas==1.1.5
sqlalchemy==1.4.0
requests==2.22.0
paho-mqtt==1.5.1
getmac==0.8.2
matplotlib
EOF

cat <<EOF > Dockerfile.$POSTFIX
FROM python:$PYTHON_VERSION-slim
USER root
COPY $SOURCE_DIR/requirements.$POSTFIX.txt /tmp/requirements.txt
RUN apt-get update \
 && apt-get upgrade -yq --no-install-recommends ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && pip install -r /tmp/requirements.txt \
 && mkdir -p /builds/app
COPY $SOURCE_DIR/ /builds/app/
WORKDIR /builds/app
ENV TZ "$TZ"
ENTRYPOINT ["python", "$APP_ENTRYPOINT"]
EOF

sudo docker rmi $APP_NAME:$APP_VERSION 2>/dev/null
sudo docker build -t $APP_NAME:$APP_VERSION --file ./Dockerfile.$POSTFIX .
rm -rf "Dockerfile.$POSTFIX"
rm -rf "requirements.$POSTFIX.txt"
rm -rf ".dockerignore"
if [ -f ".dockerignore.$POSTFIX.bak" ]; then mv -f .dockerignore.$POSTFIX.bak .dockerignore; fi

if [ -z "$JENKINS_HOME" ]; then exit 0; fi

# JENKINS post procedure: save docker image to nfs
DEST_DIR=/media/nfs/jenkins/$JOB_NAME
sudo rm -rf $DEST_DIR/$APP_NAME/$APP_VERSION/$BUILD_TAG.tar.gz
sudo mkdir -p $DEST_DIR/$APP_NAME/$APP_VERSION
sudo chmod -R 777 $DEST_DIR/$APP_NAME/$APP_VERSION
sudo docker save $APP_NAME:$APP_VERSION | gzip > $DEST_DIR/$APP_NAME/$APP_VERSION/$APP_NAME"_"$APP_VERSION"_"$(date +"%Y_%m_%d_%I_%M_%p").tar.gz

# JENKINS post procedure: test run
CONTAINER_NAME=testrun-$POSTFIX
TEST_SEC=9
sudo docker run --rm -d --name $CONTAINER_NAME $APP_NAME:$APP_VERSION
sleep $TEST_SEC
if [ "$(sudo docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "running for $TEST_SEC seconds"
else
    echo "stop before $TEST_SEC seconds"
    exit 1
fi
sudo docker stop $CONTAINER_NAME
