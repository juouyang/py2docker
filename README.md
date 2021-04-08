# Pack Python Project into Docker Image

## Prerequirements
Bash version 4.x+, docker, and internet connection 

## Build Steps

1. Create a folder named `py2docker` in your python project 
2. Add a new file in the folder py2docker, and named it `<yourappname>.conf`
3. Edit `<yourappname>.conf` and input the string of following keys
4. Create or edit requirements.txt (for pip) inside the folder py2docker
5. Run script to build:

   ```bash <(curl -s https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh)```
   

## `<yourappname>.conf`:
   ``` 
   PYTHON_VERSION='<python_version>' 
   APP_NAME=' <your_app_name> ' 
   APP_VERSION=' <your_app_version> ' 
   APP_ENTRYPOINT=' <yourappmain> ' 
``` 

## Example Project 
### Folder Structure 

```
hello/
├── py2docker/ 
│   ├── requirements.txt 
│   └── hello.conf 
└── hello.py 
 ```

### hello.conf
   ``` 
   PYTHON_VERSION='3.7' 
   APP_NAME='hello' 
   APP_VERSION='v0.1' 
   APP_ENTRYPOINT='hello.py' 
   ``` 

### requirements.txt 
   ```
schedule==1.0.0
lineTool==1.0.3
pandas==1.1.5
sqlalchemy==1.4.0
requests==2.22.0
paho-mqtt==1.5.1
shioaji==0.3.1.dev8
psutil==5.8.0
getmac==0.8.2
```

### Build 
   ```
   cd hello/
   curl https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh | bash
   ```
