
Lista Build:
    - PR Dockerfile
        - Hacer script (builder + runner)
    - PR GH Action
    - Actualizar jvm.prod.options
    - Añadir VERSION
    - Nombre de paquetes

Posible problema:
    el build min llama a la carpeta de seguridad `security`, pero en los 
    paquete de producción se llama `opensearch-security`. A resolver en `Assembly`


```bash
bash scripts/build.sh -v 2.11.0 -s false -p linux -a x64 -d rpm
```

Deja los paquetes en `artifacts/`

```bash
Usage: scripts/build.sh [args]


Arguments:
-v VERSION      [Required] OpenSearch version.
-q QUALIFIER    [Optional] Version qualifier.
-s SNAPSHOT     [Optional] Build a snapshot, default is 'false'.
-p PLATFORM     [Optional] Platform, default is 'uname -s'.
-a ARCHITECTURE [Optional] Build architecture, default is 'uname -m'.
-d DISTRIBUTION [Optional] Distribution, default is 'tar'.
-o OUTPUT       [Optional] Output path, default is 'artifacts'.
-h help
```


Soporte:

```bash
    linux-tar-x64|darwin-tar-x64)
        PACKAGE="tar"
        EXT="tar.gz"
        TYPE="archives"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    linux-tar-arm64|darwin-tar-arm64)
        PACKAGE="tar"
        EXT="tar.gz"
        TYPE="archives"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
        ;;
    linux-deb-x64)
        PACKAGE="deb"
        EXT="deb"
        TYPE="packages"
        TARGET="deb"
        SUFFIX="amd64"
        ;;
    linux-deb-arm64)
        PACKAGE="deb"
        EXT="deb"
        TYPE="packages"
        TARGET="arm64-deb"
        SUFFIX="arm64"
        ;;
    linux-rpm-x64)
        PACKAGE="rpm"
        EXT="rpm"
        TYPE="packages"
        TARGET="rpm"
        SUFFIX="x86_64"
        ;;
    linux-rpm-arm64)
        PACKAGE="rpm"
        EXT="rpm"
        TYPE="packages"
        TARGET="arm64-rpm"
        SUFFIX="aarch64"
        ;;
    windows-zip-x64)
        PACKAGE="zip"
        EXT="zip"
        TYPE="archives"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    windows-zip-arm64)
        PACKAGE="zip"
        EXT="zip"
        TYPE="archives"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
```


Probando workflow en act:

```
act -j build -W .github/workflows/build.yml --artifact-server-path ./artifacts

[Build slim packages/build] 🏁  Job succeeded
```