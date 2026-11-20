# 上游同步固定路线

这份文档是隐私构建的维护合同。目标不是“永远不冲突”，而是**冲突时只重放这些小分支，不重写上游逻辑**。

> 下文 `app/android/...` = `app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app`。

当前策略（改之前先看这里）：

- `dsh_session_log` **保留**（官方 API 请求继续带）；
- `dsh_plugin_packages` **关闭**；
- OTel feedback、`/feedback`、点赞点踩 **关闭**；
- App 匿名统计 **关闭**；
- 插件市场 **关闭**（不隐藏已安装插件）；
- Google ML Kit **不初始化**；
- App 内更新 **全关**（手动侧载）。

---

## 1. 同步前

隐私改动单独放在一个分支上，例如 `privacy`。不要把隐私改动混进 upstream 的 merge commit。

```bash
git switch privacy
git status                 # 必须干净；有未提交改动先自己备份
git tag privacy-before-$(date +%Y%m%d)
git fetch upstream
```

如果工作区有用户或其他任务的未提交改动：不要 `reset`、`stash` 或覆盖，先停下来处理。

## 2. 同步

推荐 rebase，让隐私提交始终在最上面：

```bash
git config rerere.enabled true   # 可选：记住重复冲突的解法
git rebase upstream/main
```

也可以 merge，但之后冲突会集中在同一次 merge 里，不如 rebase 好定位。

冲突文件只可能是 `privacy/README.md`、`privacy/SYNC.md` 和下面这些带 `privacy:` 注释的文件。解决原则：

- **保留上游的新逻辑**；
- 把 `privacyBuild` / `PrivacyBuild` 的小分支重新加回去；
- 不要为了省冲突把整段上游代码替换成旧版本。

## 3. 冲突重放清单

### 3.1 App 匿名统计

文件：

- `app/lib/usage/usage_net.dart`
- `app/lib/usage/usage_stats.dart`
- `app/lib/ui/settings/usage_stats_section.dart`
- `app/lib/ui/onboarding/usage_notice_row.dart`

必须保留：

```dart
const usageDisabledByBuild = privacyBuild || bool.fromEnvironment('DSH_USAGE_DISABLED');

static bool active = !usageDisabledByBuild && (kReleaseMode || ...);
```

```dart
final enabled = !usageDisabledByBuild && (prefs.getBool(enabledKey) ?? true);
if (usageDisabledByBuild) {
  for (final key in [daysKey, iidKey, iidSinceKey, failedAtKey, closedDayKey, enabledKey]) {
    await prefs.remove(key);
  }
}
```

```dart
if (usageDisabledByBuild) enabled = false;
```

UI：`forcedOff = usageDisabledByBuild`，开关 `onChanged` 为 null，首次引导行隐藏。

### 3.2 更新

文件：

- `app/lib/state/update_state.dart`
- `app/lib/ui/update/update_tiles.dart`
- `app/lib/ui/update/update_sheet.dart`
- `app/lib/ui/chat/chat_list.dart`

必须保留：

```dart
if (privacyBuild) return false;                    // autoCheckIfDue
if (privacyBuild) return UpdateCheckPhase.idle;    // check
if (privacyBuild || _noticeOnly) return;           // startDownload / install
```

加载完成后调用 `_privacyOff()`，它会清掉 `latest`、`check`、`autoCheck` 和 `installable`。

UI：`AppUpdateTiles` 在 `privacyBuild || !update.checkable` 时返回空；`checkForUpdates` 在 `privacyBuild` 时直接返回；聊天里的「检查更新」动作不显示。

### 3.3 插件市场

文件：

- `app/lib/state/plugins_state.dart`（import `privacyBuild`）
- `app/lib/state/plugins/plugin_market.dart`
- `app/lib/ui/plugins/plugins_screen.dart`
- `app/lib/ui/plugins/installed_tab.dart`

必须保留：

```dart
// fetchMarketFile
if (privacyBuild) throw const MarketFetchException('market disabled');
```

```dart
// marketCatalogProvider / officialMarketProvider
if (privacyBuild) {
  return MarketCatalog(MarketIndex(url: ..., title: LocalizedText.plain('')));
}
```

UI：`PluginsScreen` 只显示「已安装」；`InstalledPluginsSliver.onBrowse` 为 null 时不显示「浏览市场」。

### 3.4 ML Kit

文件：

- `app/android/.../privacy/PrivacyBuild.kt`
- `app/android/.../MainActivity.kt`
- `app/android/.../mlkit/MlKitRuntime.kt`
- `app/android/.../phone/a11y/MlKitLocalOcr.kt`
- `app/android/.../phone/a11y/MlKitSession.kt`
- `app/lib/ui/remote/pairing_page.dart`
- `app/lib/ui/phone/phone_control_screen.dart`
- `app/lib/ui/settings/privacy_page.dart`

必须保留：

```kotlin
object PrivacyBuild {
    const val DISABLE_ML_KIT = true
    const val DISABLE_ENGINE_TELEMETRY = true
}
```

- `MlKitRuntime.initialize` 先 `check(!PrivacyBuild.DISABLE_ML_KIT)`；
- `MlKitLocalOcr` 的 `switchedOn` 和 `setEnabled` 都受 `DISABLE_ML_KIT` 限制；
- `MlKitSession.create` 再 guard 一次；
- `MainActivity.initializePairingScanner` 直接返回 `privacy_mlkit_disabled`；
- Dart 侧：扫码页显示占位、保留「粘贴配对链接」；OCR 设置隐藏。

### 3.5 引擎遥测

文件：

- `app/android/.../runtime/RuntimeController.kt`
- `app/android/.../runtime/AppAuthGuest.kt`

必须保留：

```kotlin
if (PrivacyBuild.DISABLE_ENGINE_TELEMETRY) env["DSH_TELEMETRY_DISABLED"] = "1"
```

`AppAuthGuest.PATCH_YAML` 必须保留这段：

```yaml
# privacy: no plugin inventory, no feedback upload or feedback entry. The
# session-log field stays (the person asked to keep it).
- id: session-telemetry-otel
  disabled: true
- id: plugin-package-inventory-deepseek
  disabled: true
- id: command-feedback
  disabled: true
- id: message-feedback
  disabled: true
```

**不要**再加 `session-log-deepseek` 的禁用行；`privacy/check.sh` 会 `forbid` 它。

## 4. 检查新上游是否引入新遥测

`privacy/check.sh` 只能检查已知 gate，不能发现上游新增的 endpoint。同步后额外跑：

```bash
git diff privacy-before..upstream/main -- \
  app/lib/usage \
  app/lib/state/update_state.dart \
  app/lib/state/plugins \
  app/lib/ui/plugins \
  app/lib/ui/update \
  app/lib/ui/remote \
  app/lib/ui/phone \
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/mlkit \
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime
```

重点搜索：

```bash
grep -RIn "telemetry\|analytics\|MlKit\|initializePairingScanner\|usage/v1\|dsh-otel\|dshfind\|market\|jsdelivr\|unpkg" \
  app/lib app/android/app/src/main
```

看到新的外发点，按“后台/自动”与“用户主动功能”分类：

- 后台/自动：加 gate 或 overlay；
- 用户主动：确认是否必须，必要时加提示或隐藏；
- 新请求字段：如果只是官方 API 的额外元数据，默认关掉；如果确需保留，写进本文档的“当前策略”。

## 5. 自动检查

```bash
bash privacy/check.sh
```

必须输出：

```text
privacy gates present
```

失败时按提示补回对应 gate；如果是上游改了文件名/row id，同时更新 `privacy/check.sh` 和 `AppAuthGuest` 的 row id。

## 6. 构建

在 Linux 构建机（Flutter/Android SDK/NDK、`runtime/out/<abi>`）：

```bash
privacy/build.sh --dry-run -f arm64
privacy/build.sh -f arm64 --build-name <下一个版本号>
```

`privacy/build.sh` 会固定传 `--dart-define=DSH_PRIVACY=1`。不要直接跑 `tooling/build-apk.sh` 出隐私包，否则 App 侧的统计/更新/市场/ML Kit gate 不会生效。

构建前在有 Flutter 的环境跑：

```bash
(cd app && flutter analyze && flutter test)
```

## 7. 真机验证

静态检查不是证明。至少做一次：

1. 用 mitmproxy / PC 代理 / `tcpdump` 看空闲启动：
   - 不应有 `google`、`go.dshtui.com/api/usage`、`dsh-otel-collector`、`dshfind`、市场 bucket 请求；
   - 更新检查不应发生。
2. 打开插件页：
   - 只有「已安装」，没有「插件市场」；
   - 已安装插件的开关/移除仍可用。
3. 打开配对页：
   - 没有相机预览；粘贴配对链接仍可用；
   - 不应初始化 ML Kit。
4. 发一轮官方 API 请求（测试账号）：
   - `dsh_session_log` **应该存在**；
   - `dsh_plugin_packages` **不应存在**。
   用受控代理/本地测试端查看，别把真实 API Key 写进日志。
5. 打开设置 → 关于：
   - 没有检查更新/自动更新行。

## 8. 记录

每次同步后建议在 PR/提交说明里写一行：

```text
privacy sync: upstream <commit>, check.sh OK, device idle traffic OK
```

不必维护单独的台账；提交历史 + `check.sh` 输出足够。

## 9. 如果上游重写了某个文件

优先做“最小重放”：

- 重新加 `if (privacyBuild)` 分支；
- 不要回滚上游新逻辑；
- 不要为了减少冲突把隐私构建变成一个大 patch 文件；
- 如果某个 gate 已经无法用一行分支表达，先在 PR 里说明，再改 `SYNC.md` 和 `check.sh`。

上游改得越多，越应该保持隐私改动是**少量、可搜索、每处带 `privacy:` 注释**的提交。
