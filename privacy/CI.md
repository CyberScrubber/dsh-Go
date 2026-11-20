# CI 打包（本机只下载 APK）

这是本机空间最少的路线：runtime 和 APK 都在 GitHub Actions 的 Ubuntu runner 上构建，本机不装 Docker/Flutter/Android SDK。

工作流：[.github/workflows/privacy-apk.yml](../.github/workflows/privacy-apk.yml)

## 使用

先把工作流文件放到**默认分支**（GitHub 只允许默认分支上的 `workflow_dispatch` 出现在 Actions 里），之后用 `--ref privacy` 针对 privacy 分支构建：

```bash
gh workflow run privacy-apk.yml --ref privacy -f version=1.2.1

gh run list --workflow privacy-apk.yml
gh run watch <run-id>

# 下载 APK artifact
gh run download <run-id> -n dsh-go-privacy-arm64-1.2.1 -D /tmp/dshgo-apk
```

`/tmp/dshgo-apk` 里是：

```text
app-arm64-release.apk
```

也可以直接在 GitHub 网页的 Actions → 这次 run → Artifacts 里下载；在手机上登录 GitHub 下载 zip 也可以，不经过电脑。

装完就可以删掉本地 zip；APK 本身约 700MB。

## 签名

不配置 secrets 时，CI 用 runner 的 debug key：

- 可以装；
- 不能覆盖官方安装，先卸载；
- 每次 CI 的 debug key 可能不同，跨次更新也可能要卸载重装。

要稳定升级，先生成一把自己的 key（本机只需要 JDK 的 `keytool`，不占空间）：

```bash
keytool -genkeypair -v \
  -keystore "$HOME/keys/dshgo-private.jks" \
  -alias dshgo \
  -keyalg RSA -keysize 4096 -validity 10000

# 从 stdin 写入，避免密钥出现在 shell 历史和命令行参数里
base64 < "$HOME/keys/dshgo-private.jks" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
read -rsp 'keystore password: ' KEYSTORE_PASSWORD; echo
printf '%s' "$KEYSTORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body dshgo
read -rsp 'key password: ' KEY_PASSWORD; echo
printf '%s' "$KEY_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD
unset KEYSTORE_PASSWORD KEY_PASSWORD
```

密钥只放仓库外；丢了就无法覆盖升级。不要提交 `.jks` 或 `key.properties`。

## 触发内容

`runtime` job：

- 构建 `runtime/out/arm64-v8a`；
- 校验 `check_runtime_bundle.py`；
- 上传 `privacy-runtime-arm64-v8a`。

`apk` job：

- 下载同一 run 的 runtime；
- 装 Flutter 3.47.7、JDK 17、Gradle 9.3.1、NDK 28.2.13676358；
- 跑 `privacy/check.sh`；
- 用 `privacy/build.sh` 出 APK；
- 上传 `dsh-go-privacy-arm64-<version>`。

## 公开 fork + 自用升级

公开 fork 也能用：

- Actions 对公开仓库通常免费；
- secrets 是加密的，PR 工作流拿不到；这个工作流只有 `workflow_dispatch`，不会在别人 PR 上跑；
- artifact 需要登录有仓库读权限的 GitHub 账号才能下载，构建日志里没有密钥。

第一次从官方版/debug 版切到自己的固定 key：

```bash
adb uninstall io.github.ccch1mneyyy.dsh_app
adb install app-arm64-release.apk
```

之后每次升级只需要：

```bash
adb install -r app-arm64-release.apk
```

或者在手机上直接点新 APK 覆盖安装。对话、设置和 Linux 环境会保留。

`version` 要给一个比当前更高的版本名；`versionCode` 由 `tooling/build-apk.sh` 按构建分钟自动生成，所以后构建的版本一定更高。如果安装时报降级，等一分钟再跑一次，或给 `privacy/build.sh` 加 `-n <更大的数字>`。

## 注意

- 公开仓库的 Actions 通常免费；私有 fork 会消耗 minutes，runtime 最长 45 分钟。
- artifact 只保留 3 天，构建完尽快下载。
- CI 只构建代码，不接触你的 API Key、对话或手机数据。
- 这是 debug/自签 APK；不要发布到应用商店，也不要用它覆盖官方签名版本。
- 如果 workflow 失败，先看失败 job 的日志：runtime 多半是下载/缓存，APK 多半是 NDK、Gradle 或签名。
