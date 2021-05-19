#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d%H%M%S.%3N")
POSTFIX=$RANDOM
PYTHON_VERSION='3.8'
STRATEGY_NAME=$(basename "$PWD")

# check entrypoint
if [ -f "__main__.py" ] && [ "$(ls -la *.py | grep -v __main__.py | wc -l)" == "1"  ]; then
  APP_ENTRYPOINT="__main__.py" # strategy template
elif [ -f "__main__.py" ]; then
  APP_ENTRYPOINT="__main__.py"
else
  #echo -n "Input filename.py of entrypoint: "
  #read APP_ENTRYPOINT
  APP_ENTRYPOINT="${APP_ENTRYPOINT:=ValleyExpressSelect.py}"
fi
if [ ! -f "$APP_ENTRYPOINT" ]; then echo "Entrypoint: $APP_ENTRYPOINT not found" && exit 300; fi

# check docker
if [ ! -x "$(command -v docker)" ]; then echo "Access https://docs.docker.com/engine/install/, and install docker first." && exit 301; fi
DOCKER_REPOSITORY=$(basename $(dirname "$PWD"))"/"$(basename "$PWD") # userID/strategyID
DOCKER_REPOSITORY=$DOCKER_REPOSITORY
DOCKER_REPOSITORY="${DOCKER_REPOSITORY,,}"
DOCKER_REPOSITORY="${DOCKER_REPOSITORY// /_}"
DOCKER_TAG=$TIMESTAMP
DOCKER_TAG="${DOCKER_TAG,,}"
CONTAINER_NAME=$(basename $(dirname "$PWD"))"-"$(basename "$PWD") # userID-strategyID

# generate .dockerignore
if [ -f ".dockerignore" ]; then mv -f .dockerignore .dockerignore.$POSTFIX.bak; fi
cat <<EOF > .dockerignore
**/.staging
**/log*
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

# generate requirements.txt
cat <<EOF > requirements.$POSTFIX.txt
schedule==1.0.0
lineTool==1.0.3
pandas==1.1.5
sqlalchemy==1.4.0
requests==2.22.0
paho-mqtt==1.5.1
getmac==0.8.2
EOF
if [ $(grep -inr --include \*.py -R "matplotlib" | wc -l) -ne 0 ]; then echo "matplotlib==3.4.1" >> requirements.$POSTFIX.txt; fi
if [ $(grep -inr --include \*.py -R "shioaji" | wc -l) -ne 0 ]; then echo "shioaji==0.3.1.dev8" >> requirements.$POSTFIX.txt; fi
if [ $(grep -inr --include \*.py -R "Crypto" | wc -l) -ne 0 ]; then echo "pycryptodome==3.10.1" >> requirements.$POSTFIX.txt; fi

# generate wrapper_script.sh
if [ $APP_ENTRYPOINT = "ValleyExpressSelect.py" ]; then
cat <<EOF > my_wrapper_script.sh
#!/bin/bash
python $APP_ENTRYPOINT
while true
do
  currentTime=\$(TZ=":Asia/Taipei" date +"%H%M")
  echo -n .
  if [ "\$currentTime" == "0600" ]; then
    echo "Triggered at "\$currentTime
    RC=1
    while [ \$RC -ne 0 ]
    do
      python $APP_ENTRYPOINT
      RC=\$?
      echo "RC="\$RC
      if [ \$RC != 0 ]; then
        echo "Failed"
      fi
    done
  fi
  sleep 60
done
EOF
elif [ -f "./TradeBot.py" ]; then
cat <<EOF > my_wrapper_script.sh
#!/bin/bash
while true
do
  python $APP_ENTRYPOINT
  echo "will restart TradeBot in 3 sec ..."
  sleep 3
done
EOF
else # strategy template
cat <<EOF > my_wrapper_script.sh
#!/bin/bash
python $APP_ENTRYPOINT
EOF
fi
chmod +x my_wrapper_script.sh

# generate Dockerfile
TZ="${TZ:=Asia/Taipei}"
cat <<EOF > Dockerfile.$POSTFIX
FROM python:$PYTHON_VERSION-slim
USER root
COPY requirements.$POSTFIX.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt \
 && mkdir -p /builds/app
COPY ./ /builds/app/
WORKDIR /builds/app
ENV TZ "$TZ"
COPY my_wrapper_script.sh my_wrapper_script.sh
CMD bash
ENTRYPOINT ./my_wrapper_script.sh
EOF

# docker build
sudo docker rmi $DOCKER_REPOSITORY:$DOCKER_TAG &> /dev/null
sudo docker build -t $DOCKER_REPOSITORY:$DOCKER_TAG --file ./Dockerfile.$POSTFIX . | sed -nr '/^Step|tagged/p'
BUILD_RC=$?
rm -rf "my_wrapper_script.sh"
rm -rf "Dockerfile.$POSTFIX"
rm -rf "requirements.$POSTFIX.txt"
rm -rf ".dockerignore"; if [ -f ".dockerignore.$POSTFIX.bak" ]; then mv -f .dockerignore.$POSTFIX.bak .dockerignore; fi

# generate staging folder
STAGING_DIR="./.staging"
if [ $(grep -inr --include \*.py -R "'logs'" | wc -l) -ne 0 ]; then
  LOG_DIR="logs"
else
  LOG_DIR="log"
fi
mkdir -p $STAGING_DIR"/"$LOG_DIR
chmod -R 777 $STAGING_DIR

# generate run.sh
cat <<EOF > $STAGING_DIR"/run.sh"
if [ \$(ip addr | grep 192.168.233 | wc -l) -ne 0 ]; then
  MQTT_IP=192.168.233.134
  MQTT_PORT=1883
  VOLUME_DEVICE="//192.168.233.190/Knowledge"
  VOLUME_OPT_O="username=dl.chiu,password=chiu123456,vers=1.0"
elif [ \$(ip addr | grep 192.168.238 | wc -l) -ne 0 ]; then
  MQTT_IP=192.168.238.100
  MQTT_PORT=5883
  VOLUME_DEVICE="//192.168.238.100/rep"
  VOLUME_OPT_O="username=jetson_nano,password=jn@123456"
fi
MQTT_IP="\${MQTT_IP:=192.168.238.100}"
MQTT_PORT="\${MQTT_PORT:=5883}"
EOF
if [ -f "./TradeBot.py" ]; then
mkdir -p $STAGING_DIR"/AccountPassword"
cp -rf ../AccountPassword/* $STAGING_DIR"/AccountPassword"
cat <<EOF >> $STAGING_DIR"/run.sh"
docker load < "$STRATEGY_NAME-$TIMESTAMP.tar"
docker run --rm -it \
  -e MQTT_IP=\$MQTT_IP \
  -e MQTT_PORT=\$MQTT_PORT \
  -v \$(pwd)/$LOG_DIR/:/builds/app/$LOG_DIR \
  -v \$(pwd)/AccountPassword/Config.json:/builds/app/reference/Config.json \
  -v \$(pwd)/AccountPassword/private_key.pem:/builds/app/reference/private_key.pem \
  -v \$(pwd)/AccountPassword/Sinopac.pfx:/builds/app/reference/Sinopac.pfx \
  --name $CONTAINER_NAME \
  $DOCKER_REPOSITORY:$DOCKER_TAG
EOF
elif [ -f "./ValleyExpressSelect.py" ]; then
cat <<EOF >> $STAGING_DIR"/run.sh"
docker load < "$STRATEGY_NAME-$TIMESTAMP.tar"
docker volume rm rep
docker volume create \
  --driver local \
  --opt type=cifs \
  --opt device=\$VOLUME_DEVICE \
  --opt o=\$VOLUME_OPT_O \
  --name rep
docker volume inspect rep
docker run --rm -it \
  -e MQTT_IP=\$MQTT_IP \
  -e MQTT_PORT=\$MQTT_PORT \
  -v \$(pwd)/$LOG_DIR/:/builds/app/$LOG_DIR \
  -v rep:/builds/rep \
  --name $CONTAINER_NAME \
  $DOCKER_REPOSITORY:$DOCKER_TAG
EOF
else # strategy
cat <<EOF >> $STAGING_DIR"/run.sh"
docker load < "$STRATEGY_NAME-$TIMESTAMP.tar"
docker run --rm -it \
  -e MQTT_IP=\$MQTT_IP \
  -e MQTT_PORT=\$MQTT_PORT \
  -v \$(pwd)/$LOG_DIR/:/builds/app/$LOG_DIR \
  -v rep:/builds/rep \
  --name $CONTAINER_NAME \
  $DOCKER_REPOSITORY:$DOCKER_TAG
EOF
fi

# save docker image
if [ ! -z "$JENKINS_HOME" ]; then
  ### JENKINS
  DEST_DIR=/media/nfs/jenkins/$JOB_NAME
else
  DEST_DIR=$STAGING_DIR
fi
echo saving docker image ...
sudo rm -rf $DEST_DIR/$STRATEGY_NAME-$TIMESTAMP.tar
sudo mkdir -p $DEST_DIR
sudo chmod -R 777 $DEST_DIR
sudo docker save $DOCKER_REPOSITORY:$DOCKER_TAG > $DEST_DIR/$STRATEGY_NAME-$TIMESTAMP.tar
echo docker image saved with RC=$?

echo "Build complete with return code "$BUILD_RC
exit $BUILD_RC
