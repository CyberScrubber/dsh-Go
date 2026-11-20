# Docker 打包

Docker 可以完整解决 Mac 打包：在 `linux/amd64` 容器里跑 Flutter/Android SDK/NDK，顺便构建 arm64 runtime，最后把 APK 写回仓库。

限制：

- Apple Silicon 需要 Docker Desktop 开启 **Rosetta for x86/amd64**；`runtime/build-runtime.sh` 要求 x86_64 Linux 宿主。
- 容器里没有 USB/adb，**打包在容器，安装用 Mac 的 adb**。
- 首次构建镜像很大（Flutter + Android SDK/NDK + 模拟器镜像），预留 20GB+ 磁盘和 8GB+ 内存。
- 容器内没有 release keystore 时，Gradle 回落到 debug key；不能覆盖官方安装。

## 一键构建

```bash
# 第一次会构建工具链镜像，比较久
privacy/docker/build.sh 1.2.1

# 模拟器 x64
FLAVOR=x64 privacy/docker/build.sh 1.2.1
```

产物仍在：

```text
app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

## 只让 Docker 构建 runtime

如果你已经在 Mac 上装好 Flutter/Android SDK，只缺 Linux runtime：

```bash
docker run --rm --platform linux/amd64 \
  -v "$PWD":/src -w /src \
  ubuntu:24.04 \
  bash -lc '
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl file git gpgv python3 unzip xz-utils &&
    bash runtime/build-runtime.sh arm64-v8a
  '
```

然后在 Mac 上：

```bash
python3 -I tooling/check_runtime_bundle.py arm64
privacy/build.sh -f arm64 --build-name 1.2.1
```

## 签名

容器默认用镜像里的 debug keystore。要固定签名，把 keystore 挂到 `/keys`，并在仓库里放一个只给容器用的 `app/android/key.properties`：

```properties
storeFile=/keys/dshgo-private.jks
storePassword=...
keyAlias=dshgo
keyPassword=...
```

运行：

```bash
docker run ... -v "$HOME/keys":/keys:ro ...
```

不要把 `key.properties` 提交；Mac 本地构建时它的 `/keys/...` 路径不存在，需要另写一份或改用环境变量。

## 安装

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

签名冲突时先卸载旧版；卸载会清空对话、Linux 环境和设置。

## 兜底

如果 Docker Desktop 的 Rosetta 不稳定，或者构建中 NDK/Gradle 出问题，直接走 Linux 构建机路线（[BUILD.md](../BUILD.md) 路线 B）。Docker 只是把 Linux 构建机装进容器，不改变这条链路。
