#!/bin/bash
SUDO=''
if (( $EUID != 0 )); then SUDO='sudo'; fi
TIMESTAMP=$(TZ=":Asia/Taipei" date +"%Y%m%d%H%M%S.%3N")
POSTFIX=$RANDOM
PYTHON_VERSION='3.8'

# check entrypoint
if [ -f "__main__.py" ] && [ "$(ls -la *.py | grep -v __main__.py | wc -l)" == "1"  ]; then
  APP_ENTRYPOINT="__main__.py" # strategy template
elif [ -f "__main__.py" ]; then
  APP_ENTRYPOINT="__main__.py"
else
  # try to find entrypoint
  if [ "$(find . -maxdepth 1 -type f | xargs grep -lnRE 'if __name__|__main__' --include=*.py | wc -l)" == "1" ]; then
    ENTRYPOINT=$(find . -maxdepth 1 -type f | xargs grep -lnRE 'if __name__|__main__' --include=*.py)
    APP_ENTRYPOINT=$(basename $ENTRYPOINT)
  else
    # failed to find entrypoint
    APP_ENTRYPOINT=$TIMESTAMP.$POSTFIX
  fi
fi
if [ ! -f "$APP_ENTRYPOINT" ]; then echo "Entrypoint: $APP_ENTRYPOINT not found" && exit 300; fi

# check password
if [ -f "./TradeBot.py" ] && [ "$(ls -A1 ../AccountPassword* | wc -l)" != "3"  ]; then echo "Cannot find AccountPassword for TradeBot"; exit 1; fi

# check docker
if [ ! -x "$(command -v docker)" ]; then echo "Access https://docs.docker.com/engine/install/, and install docker first." && exit 301; fi
if [ ! -z "$JENKINS_HOME" ]; then
  ### JENKINS, JOB_NAME="groupName'userID'projectID"
  USER_ID=$(tr "'" "\n" <<< $JOB_NAME | sed -n '2p')
  PROJECT_ID=$(tr "'" "\n" <<< $JOB_NAME | sed -n '3p')
  DOCKER_REPOSITORY=$(tr \' \/ <<< $JOB_NAME) # groupName/userID/projectID
  CONTAINER_NAME=$USER_ID"-"$PROJECT_ID # CONTAINER_NAME=userID-projectID
  STAGING_DIR=/media/nfs/jenkins/$DOCKER_REPOSITORY/$TIMESTAMP
  SAVED_DOCKER_IMAGE_FILE_NAME=$CONTAINER_NAME"-"$TIMESTAMP"_"$GIT_COMMIT".tar.gz"
else
  ### groupName/
  ### └── userID
  ###   └── projectID
  # PROJECT_ID=$(basename "$PWD")
  DOCKER_REPOSITORY=$(basename $(dirname $(dirname "$PWD")))"/"$(basename $(dirname "$PWD"))"/"$(basename "$PWD") # groupName/userID/projectID
  CONTAINER_NAME=$(basename $(dirname "$PWD"))"-"$(basename "$PWD") # CONTAINER_NAME=userID-projectID
  STAGING_DIR="./.staging"
  SAVED_DOCKER_IMAGE_FILE_NAME=$CONTAINER_NAME"-"$TIMESTAMP".tar.gz"
fi
DOCKER_REPOSITORY=$DOCKER_REPOSITORY
DOCKER_REPOSITORY="${DOCKER_REPOSITORY,,}"
DOCKER_REPOSITORY="${DOCKER_REPOSITORY// /_}"
DOCKER_TAG=$TIMESTAMP
DOCKER_TAG="${DOCKER_TAG,,}"

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
if [ -f "requirements.txt" ]; then mv -f requirements.txt requirements.txt.$POSTFIX.bak; fi
cat <<EOF > requirements.txt
schedule==1.0.0
lineTool==1.0.3
pandas==1.1.5
sqlalchemy==1.4.0
requests==2.22.0
paho-mqtt==1.5.1
getmac==0.8.2
wget
EOF
if [ $(grep -inr --include \*.py -R "matplotlib" | wc -l) -ne 0 ]; then echo "matplotlib==3.4.1" >> requirements.txt; fi
if [ $(grep -inr --include \*.py -R "shioaji" | wc -l) -ne 0 ]; then echo "shioaji==0.3.1.dev8" >> requirements.txt; fi
if [ $(grep -inr --include \*.py -R "Crypto" | wc -l) -ne 0 ]; then echo "pycryptodome==3.10.1" >> requirements.txt; fi

# generate wrapper_script.sh
if [ $APP_ENTRYPOINT = "ValleyExpressSelect.py" ]; then
cat <<EOF > my_wrapper_script.sh
#!/bin/bash
python $APP_ENTRYPOINT
while true
do
  currentTime=\$(TZ=":Asia/Taipei" date +"%H%M")
  echo -n .
  if [ "\$currentTime" == "0810" ]; then
    echo "Trigger $APP_ENTRYPOINT at Asia/Taipei "\$(TZ=":Asia/Taipei" date)
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
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt \
 && mkdir -p /builds/app
COPY ./ /builds/app/
WORKDIR /builds/app
ENV TZ "$TZ"
COPY my_wrapper_script.sh my_wrapper_script.sh
CMD bash
ENTRYPOINT ./my_wrapper_script.sh
EOF
if [ $(grep -inr --include \*.py -R "from mqtt_client import Client" | wc -l) -ne 0 ]; then
# install mqtt_client, custom package of Doquant
cat <<EOF >> Dockerfile.$POSTFIX
RUN python -m wget https://github.com/juouyang-aicots/py2docker/raw/main/mqtt_client_d1656173.tar -o /tmp/mqtt_client.tar \
  && mkdir -p /usr/local/lib/python3.8/site-packages/mqtt_client/ \
  && tar -xf /tmp/mqtt_client.tar -C /usr/local/lib/python3.8/site-packages/mqtt_client/
EOF
fi

# docker build
$SUDO docker rmi $DOCKER_REPOSITORY:$DOCKER_TAG &> /dev/null
$SUDO docker build -t $DOCKER_REPOSITORY:$DOCKER_TAG --file ./Dockerfile.$POSTFIX . | sed -nr '/^Step|tagged/p'
BUILD_RC=$?
rm -rf "my_wrapper_script.sh"
rm -rf "Dockerfile.$POSTFIX"
rm -rf "requirements.txt"; if [ -f "requirements.txt.$POSTFIX.bak" ]; then mv -f requirements.txt.$POSTFIX.bak requirements.txt; fi
rm -rf ".dockerignore"; if [ -f ".dockerignore.$POSTFIX.bak" ]; then mv -f .dockerignore.$POSTFIX.bak .dockerignore; fi

# generate staging folder
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
PS3='Please enter AccountType: '
options=("futures" "stock")
select opt in "\${options[@]}"
do
  case \$opt in
    "futures")
      echo "you chose choice \$REPLY which is \$opt"
      break
      ;;
    "stock")
      echo "you chose choice \$REPLY which is \$opt"
      break
      ;;
    *)
      echo "invalid option \$REPLY"
      exit 1
      ;;
  esac
done
docker load < "$SAVED_DOCKER_IMAGE_FILE_NAME"
docker run --rm -it \
  -e MQTT_IP=\$MQTT_IP \
  -e MQTT_PORT=\$MQTT_PORT \
  -e AccountType=\$opt \
  -v \$(pwd)/$LOG_DIR/:/builds/app/$LOG_DIR \
  -v \$(pwd)/AccountPassword/Config.json:/builds/app/reference/Config.json \
  -v \$(pwd)/AccountPassword/private_key.pem:/builds/app/reference/private_key.pem \
  -v \$(pwd)/AccountPassword/Sinopac.pfx:/builds/app/reference/Sinopac.pfx \
  --name $CONTAINER_NAME-\$opt \
  $DOCKER_REPOSITORY:$DOCKER_TAG
EOF
elif [ -f "./ValleyExpressSelect.py" ]; then
cat <<EOF >> $STAGING_DIR"/run.sh"
docker load < "$SAVED_DOCKER_IMAGE_FILE_NAME"
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
docker load < "$SAVED_DOCKER_IMAGE_FILE_NAME"
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
echo saving docker image ...
$SUDO rm -rf $STAGING_DIR/$SAVED_DOCKER_IMAGE_FILE_NAME
$SUDO mkdir -p $STAGING_DIR
$SUDO chmod -R 777 $STAGING_DIR
$SUDO docker save $DOCKER_REPOSITORY:$DOCKER_TAG | gzip > $STAGING_DIR/$SAVED_DOCKER_IMAGE_FILE_NAME
echo docker image saved with RC=$?

# cleanup images
echo cleanup docker images ...
$SUDO docker images --format='{{.Repository}}:{{.Tag}}' --filter=reference=$DOCKER_REPOSITORY'*:*' | xargs -r $SUDO docker rmi &> /dev/null

echo "Build complete with return code "$BUILD_RC
exit $BUILD_RC
