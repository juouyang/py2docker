#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d%H%M%S.%3N")
PYTHON_VERSION='3.8'

#
: <<'END'
userID/strategyID/
.
├── __main__.py
├── Your_Strategy.py
├── reference/
└── .staging
    ├── logs
    └── run.sh
END
#

STRATEGY_NAME=$(ls -A1 *.py | grep -v __main__ | sed -e 's/\.py$//') # Your_Strategy
APP_NAME=$(basename $(dirname "$PWD"))"/"$(basename "$PWD") # userID/strategyID
APP_VERSION=$TIMESTAMP
APP_ENTRYPOINT="__main__.py"
SOURCE_DIR='.'

if [ ! -z "$JENKINS_HOME" ]; then
    ### JENKINS
    APP_NAME=$JOB_NAME"/"$STRATEGY_NAME
    APP_VERSION="r_$SVN_REVISION"
fi

DOCKER_REPOSITORY=$APP_NAME
DOCKER_REPOSITORY="${DOCKER_REPOSITORY,,}"
DOCKER_REPOSITORY="${DOCKER_REPOSITORY// /_}"
DOCKER_TAG=$APP_VERSION
DOCKER_TAG="${DOCKER_TAG,,}"
CONTAINER_NAME=$(basename $(dirname "$PWD"))"-"$(basename "$PWD") # userID-strategyID


cd $SOURCE_DIR
if [ ! -f "$SOURCE_DIR/$APP_ENTRYPOINT" ]; then echo "Entrypoint: $SOURCE_DIR/$APP_ENTRYPOINT not found" && exit 300; fi
if [ ! -x "$(command -v docker)" ]; then echo "Access https://docs.docker.com/engine/install/, and install docker first." && exit 301; fi

POSTFIX=$RANDOM

if [ -f ".dockerignore" ]; then mv -f .dockerignore .dockerignore.$POSTFIX.bak; fi
cat <<EOF > .dockerignore
**/.staging
**/log
**/logs
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

cat <<EOF > requirements.$POSTFIX.txt
schedule==1.0.0
lineTool==1.0.3
pandas==1.1.5
sqlalchemy==1.4.0
requests==2.22.0
paho-mqtt==1.5.1
getmac==0.8.2
EOF

if grep -inr --include \*.py -R "matplotlib";   then echo "matplotlib==3.4.1" >> requirements.$POSTFIX.txt;      fi
if grep -inr --include \*.py -R "shioaji";      then echo "shioaji==0.3.1.dev8" >> requirements.$POSTFIX.txt;    fi
if grep -inr --include \*.py -R "Crypto";       then echo "pycryptodome==3.10.1" >> requirements.$POSTFIX.txt;   fi

#TZ=$(cat /etc/timezone 2>/dev/null)
TZ="${TZ:=Asia/Taipei}"

cat <<EOF > Dockerfile.$POSTFIX
FROM python:$PYTHON_VERSION-slim
USER root
COPY $SOURCE_DIR/requirements.$POSTFIX.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt \
 && mkdir -p /builds/app
COPY $SOURCE_DIR/ /builds/app/
WORKDIR /builds/app
ENV TZ "$TZ"
ENTRYPOINT ["python", "$APP_ENTRYPOINT"]
EOF


sudo docker rmi $DOCKER_REPOSITORY:$DOCKER_TAG &> /dev/null
sudo docker build -t $DOCKER_REPOSITORY:$DOCKER_TAG --file ./Dockerfile.$POSTFIX . # | sed -nr '/^Step|tagged/p'
BUILD_RC=$?
rm -rf "Dockerfile.$POSTFIX"
rm -rf "requirements.$POSTFIX.txt"
rm -rf ".dockerignore"; if [ -f ".dockerignore.$POSTFIX.bak" ]; then mv -f .dockerignore.$POSTFIX.bak .dockerignore; fi


STAGING_DIR="./.staging"
mkdir -p $STAGING_DIR"/logs"
chmod -R 777 $STAGING_DIR

if [ -f "./TradeBot.py" ]; then

mkdir -p $STAGING_DIR"/AccountPassword"
cat <<EOF > $STAGING_DIR"/run.sh"
docker load < "$STRATEGY_NAME-$TIMESTAMP.tar.gz"
docker run --rm -it \
-e MQTT_IP=192.168.233.134 \
-e MQTT_PORT=1883 \
-v \$(pwd)/logs/:/builds/app/logs \
-v \$(pwd)/AccountPassword/Config.json:/builds/app/reference/Config.json \
-v \$(pwd)/AccountPassword/private_key.pem:/builds/app/reference/private_key.pem \
-v \$(pwd)/AccountPassword/Sinopac.pfx:/builds/app/reference/Sinopac.pfx \
--name $CONTAINER_NAME \
$DOCKER_REPOSITORY:$DOCKER_TAG
EOF

else

cat <<EOF > $STAGING_DIR"/run.sh"
docker load < "$STRATEGY_NAME-$TIMESTAMP.tar.gz"
docker run --rm -it \
-e MQTT_IP=192.168.233.134 \
-e MQTT_PORT=1883 \
-v \$(pwd)/logs/:/builds/app/logs \
--name $CONTAINER_NAME \
$DOCKER_REPOSITORY:$DOCKER_TAG
EOF

fi


# save docker image
DEST_DIR=$STAGING_DIR
if [ ! -z "$JENKINS_HOME" ]; then
    ### JENKINS
    DEST_DIR=/media/nfs/jenkins/$JOB_NAME
fi
echo saving docker image ...
sudo rm -rf $DEST_DIR/$STRATEGY_NAME-$TIMESTAMP.tar.gz
sudo mkdir -p $DEST_DIR
sudo chmod -R 777 $DEST_DIR
time sudo docker save $DOCKER_REPOSITORY:$DOCKER_TAG | gzip > $DEST_DIR/$STRATEGY_NAME-$TIMESTAMP.tar.gz


# test run to check if app can run for more than 9 seconds
TESTRUN_NAME=testrun-$POSTFIX-$TIMESTAMP
TEST_SEC=9
sudo docker run --rm -d --name $TESTRUN_NAME $DOCKER_REPOSITORY:$DOCKER_TAG
sleep $TEST_SEC
if [ "$(sudo docker ps -q -f name=$TESTRUN_NAME)" ]; then
    echo "running for $TEST_SEC seconds"
else
    echo "stop before $TEST_SEC seconds"
    BUILD_RC=302
fi
sudo docker stop $TESTRUN_NAME
sudo docker rmi $DOCKER_REPOSITORY:$DOCKER_TAG

#if [ "$BUILD_RC" -eq "0" ]; then
    echo "Build complete with return code "$BUILD_RC
#fi

exit $BUILD_RC
