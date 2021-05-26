cd $WORKSPACE/$PROJECT_PATH

build () {
   APP_NAME=$(echo $1 | grep -v __main__ | sed -e 's/\.py$//')
   mkdir -p $APP_NAME
   cp -rf $1 "./"$APP_NAME"/"
   cd "./"$APP_NAME"/"
   wget -qO- https://github.com/juouyang-aicots/py2docker/raw/main/Strategy_2021W21.tar | tar x
   curl -s https://raw.githubusercontent.com/juouyang-aicots/py2docker/main/build.sh | bash
   RC=$?
   cd ../;rm -rf "./"$APP_NAME"/"
   return $RC
}

build $PROJECT_NAME.py
exit $?