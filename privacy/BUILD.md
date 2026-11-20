# 本地打包

隐私包必须用 [build.sh](build.sh)，它会固定加 `--dart-define=DSH_PRIVACY=1`。

如果本机空间很小，首选 GitHub Actions 构建，本机只下载 APK：[CI.md](CI.md)。

如果不想在 Mac 上单独装 Flutter/Android SDK，也可以用 Docker：[docker/README.md](docker/README.md)。

```bash
privacy/build.sh -f arm64 --build-name 1.2.1
```

不要直接跑 `tooling/build-apk.sh` 出隐私包，否则 App 侧的统计/更新/市场/ML Kit gate 不生效。

---

## 路线 A：macOS 出 APK + CI 出 runtime（Mac 用户推荐）

Android 的 rootfs 由 `runtime/build-runtime.sh` 在 **x86_64 Linux** 上构建；macOS 不能直接跑这个脚本。可以用仓库的 Runtime workflow 构建，再把结果下载到 Mac。

### A1. 准备 Mac 工具链

需要：

- Flutter 3.47.7（Dart 3.13.4）
- JDK 17
- Android SDK：platform-tools、build-tools、platform、NDK（用 Flutter 要求的版本）
- `adb`（platform-tools）

示例：

```bash
# Flutter
curl -fL -o /tmp/flutter.zip \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.7-stable.zip
unzip -q /tmp/flutter.zip -d "$HOME/dev"
export PATH="$HOME/dev/flutter/bin:$PATH"

# JDK 17（Homebrew）
brew install openjdk@17
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"

# Android SDK：推荐装 Android Studio，用它的 SDK Manager；
# 或者用 command-line tools：
brew install --cask android-commandlinetools
export ANDROID_HOME="$HOME/Library/Android/sdk"
SDKMANAGER="$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

"$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-36" "build-tools;36.0.0" "cmake;3.22.1"
```

NDK 版本以 Flutter 的 `FlutterExtension` 为准；`flutter doctor -v` 或第一次 Gradle 构建的报错会给出确切版本，再：

```bash
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" "ndk;<报错里的版本>"
```

然后：

```bash
cd app
flutter pub get
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

### A2. 从 GitHub Actions 拿 runtime

工作流：`.github/workflows/runtime.yml`。它会构建 `runtime/out/arm64-v8a` 并上传为 `runtime-arm64-v8a`。

```bash
# 在 privacy 分支已 push 的前提下
gh workflow run runtime.yml --ref privacy

# 看运行 id
gh run list --workflow runtime.yml

# 下载到仓库根目录
gh run download <run-id> -n runtime-arm64-v8a -D runtime/out/arm64-v8a
```

检查：

```bash
python3 -I tooling/check_runtime_bundle.py arm64
```

看到 `runtime verified: arm64 ...` 才继续。

> 也可以直接用 `main` 的 runtime artifact；隐私改动在 `app/`，通常不改 runtime。但为了可复现，建议用与 privacy 分支同一提交构建的 artifact。

### A3. 出 APK

```bash
bash privacy/check.sh
privacy/build.sh -f arm64 --build-name 1.2.1
```

产物：

```text
app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

---

## 路线 B：Linux 构建机全本地（推荐用于正式/可复现）

在 x86_64 Ubuntu 24.04 上：

```bash
git clone <你的仓库> dsh-go
cd dsh-go
git switch privacy

# 安装 Flutter/Android SDK/NDK/JDK 17，写 tooling/env.sh
bash tooling/setup-toolchain.sh
source tooling/env.sh

(cd app && flutter pub get && flutter analyze && flutter test)

# 构建 arm64 rootfs（约几十分钟，首次下载较多）
bash runtime/build-runtime.sh arm64-v8a

# 出 APK
privacy/build.sh -f arm64 --build-name 1.2.1
```

`setup-toolchain.sh` 默认装 Flutter 3.47.7、JDK 17、Android SDK/NDK、模拟器；不需要模拟器可以事后删。

如果只想快速出包、已验证过 runtime，可以跳过 `build-runtime.sh`，但 `runtime/out/arm64-v8a` 必须存在且通过：

```bash
python3 -I tooling/check_runtime_bundle.py arm64
```

---

## 签名

没有 `app/android/key.properties` 时，Gradle 回落到 debug key：

- 可以装机测试；
- **不能覆盖官方安装**；签名不同，必须先卸载旧版（会清空对话、Linux 环境和设置）。

要固定自己的签名：

```bash
mkdir -p "$HOME/keys"
keytool -genkeypair -v \
  -keystore "$HOME/keys/dshgo-private.jks" \
  -alias dshgo \
  -keyalg RSA -keysize 4096 -validity 10000
```

`app/android/key.properties`（不要提交）：

```properties
storeFile=/Users/you/keys/dshgo-private.jks
storePassword=...
keyAlias=dshgo
keyPassword=...
```

验证：

```bash
apksigner verify --print-certs \
  app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

以后每次都用同一把 key，才能覆盖升级。

---

## 安装

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

如果报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`：

```bash
adb uninstall io.github.ccch1mneyyy.dsh_app
adb install app/build/app/outputs/flutter-apk/app-arm64-release.apk
```

卸载会清空对话、Linux 环境和设置。

首次启动不需要再下载 700MB：runtime 已经在 APK 的 `assets/runtime` 里，首次启动只是解压。

---

## 常见错误

| 报错 | 处理 |
|---|---|
| `flutter: command not found` | 把 Flutter `bin` 加进 `PATH` |
| `No Android SDK found` | `flutter config --android-sdk "$ANDROID_HOME"` |
| `NDK ... not installed` | `sdkmanager "ndk;<版本>"` |
| `runtime/out/... missing` | 跑 `runtime/build-runtime.sh arm64-v8a`，或下载 CI artifact |
| `check_runtime_bundle.py` 失败 | artifact 与本机 flavor/ABI 不匹配，或 runtime 没构建完 |
| `aapt2 not found` | 装 `build-tools`，或设 `ANDROID_HOME` |
| 签名不一致 | 卸载旧版，或用同一把 key |
| `flutter doctor` 报缺少 cmdline-tools | 装 Android Studio / command-line tools，并接受 licenses |
