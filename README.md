# Pack Python Project into Docker Image

## Prerequirements
Bash version 4.x+, docker, internet connection and `aicots strategy template` (as shown below)

```
userID/strategyID/
.
├── __main__.py
├── Your_Strategy.py
├── reference/
└── .staging/
    ├── log
    └── run.sh
```


### Build

in your aicots strategy folder, execute
   ```bash
curl -s https://raw.githubusercontent.com/juouyang-aicots/py2docker/main/build.sh | bash
   ```

### Run
in your aicots strategy folder, execute
  ```bash
cd .staging
bash run.sh
   ```
