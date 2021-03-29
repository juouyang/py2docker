# python_to_docker

## Pre-requirements 
docker, and internet connection 

## Build Steps

1. Create a folder named `0_app` in your python project 
2. Add a file in the folder 0_app, and named it `<yourappname>.conf`
3. Edit `<yourappname>.conf` and input the string of following keys
4. Create a file named requirements.txt, and edit it as the official pip requirement.txt 
5. Run script to build (as described bellow) 
```
bash <(curl -s https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh)
```

`<yourappname>.conf`
``` 
PYTHON_VERSION='<python_version>' 
APP_NAME=' <yourappname> ' 
APP_VERSION=' <yourappversion> ' 
APP_ENTRYPOINT=' <yourappmain> ' 
``` 
For exmaple: 
``` 
PYTHON_VERSION='3.7' 
APP_NAME='hello' 
APP_VERSION='v0.1' 
APP_ENTRYPOINT='hello.py' 
``` 


## Example Project 
### Folder Structure 

Root folder of your python project 
├── 0_app 
│   └── hello.conf 
├──1_build.sh 
├──2_test.sh 
├── requirements.txt 
└── hello.py 
 
requirements.txt 
```
requests==2.22.0 
```

Build 

```
cd <Root folder of your python project>
bash <(curl -s https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh)
```
