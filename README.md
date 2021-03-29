# Pack Python Project into Docker Image

## Prerequirements
docker, and internet connection 

## Build Steps

1. Create a folder named `py2docker` in your python project 
2. Add a new file in the folder py2docker, and named it `<yourappname>.conf`
3. Edit `<yourappname>.conf` and input the string of following keys
4. Create or edit requirements.txt (for pip) inside the folder py2docker
5. Run script to build:
```
bash <(curl -s https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh)
```

## `<yourappname>.conf`:
``` 
PYTHON_VERSION='<python_version>' 
APP_NAME=' <all_lower_case_app_name> ' 
APP_VERSION=' <all_lower_case_app_version> ' 
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

```
Root folder of your python project 
├── py2docker 
│   ├── requirements.txt 
│   └── hello.conf 
└── hello.py 
 ```
 
requirements.txt 
```
requests==2.22.0 
```

Build 

```
cd <Root folder of your python project>
curl https://raw.githubusercontent.com/juouyang-aicots/python_to_docker/main/build.sh | bash
```
