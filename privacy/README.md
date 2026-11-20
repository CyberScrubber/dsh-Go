# Privacy build

This branch can produce a build whose only network peers are:

1. the model provider you configure (DeepSeek official, or another provider you choose);
2. a desktop DSH you link to (SSH / Remote);
3. services you explicitly open yourself (workshop, community page, Mermaid
   preview, share links, web search/fetch), when you use those features.

No background analytics, no SDK usage reporting, no automatic update check.

## What is off

| What | How |
|---|---|
| dsh-go anonymous usage stats | `DSH_PRIVACY=1` → `usageDisabledByBuild`; no count, no send, old local ledger/id deleted, switch hidden/disabled |
| engine OTel feedback | `DSH_TELEMETRY_DISABLED=1` in the engine launch env; also `session-telemetry-otel` disabled in the overlay |
| `dsh_plugin_packages` inventory | `plugin-package-inventory-deepseek` disabled in the overlay |
| plugin market | `privacyBuild` returns empty market catalogs and hides the market tab; `fetchMarketFile` refuses HTTP |
| `/feedback` and message feedback | `command-feedback` / `message-feedback` disabled in the overlay |
| Google ML Kit | never initialized: camera scanner hidden, OCR hidden and forced off, native guards in `PrivacyBuild` |
| in-app updates | `privacyBuild` makes `check()` / `autoCheckIfDue()` / download / install no-ops; update UI hidden |

The overlay is written by `AppAuthGuest.PATCH_YAML` and passed to `dsh web` on
normal launches. Safe mode starts with plugins off, so it has no telemetry
either.

## What still makes a request

These are feature requests, not telemetry; they happen only when you use the
feature:

- workshop (`go.dshtui.com`);
- community page (GitHub raw / jsDelivr);
- Mermaid preview (npmmirror / jsDelivr / unpkg);
- share links / Gist (Cloudflare / GitHub);
- web search / web fetch, when the model calls those tools;
- automatic diagnostics, if you explicitly enable it (it sends a limited
  snapshot to the model provider);
- remote DSH (your computer, SSH, or the WebRTC relay).

If you also want those gone, use the stricter profile in the issue/PR that
introduced this directory: hide the entries and/or point the build-time feeds
at your own server.

`dsh_session_log` is the exception: it is deliberately **kept**. Every official
DeepSeek request still carries the incremental session log; this is the data
flow the person chose to allow. It is not model input and does not change the
conversation, but a custom `baseURL` gateway also sees it.

## Build

See [CI.md](CI.md) for the zero-local-toolchain route (GitHub Actions builds the APK), [BUILD.md](BUILD.md) for the macOS + CI-runtime route and the full Linux route, and [docker/README.md](docker/README.md) for a container build.

```bash
# Linux x86_64 build host with Flutter, Android SDK/NDK and runtime/out/<abi>
privacy/build.sh -f arm64 --build-name <next version>
```

`privacy/build.sh` adds `--dart-define=DSH_PRIVACY=1`; do not add another `--`
argument. A release build without this flag keeps upstream app behaviour for
stats and updates; the native ML Kit/engine gates are still applied. Always
use this wrapper for a privacy APK.

APK signing is unchanged: a new key cannot update the official install; uninstall
the old app first (this deletes chats and the Linux environment). See
`docs/release.md`.

## Syncing with upstream

Use the fixed runbook in [SYNC.md](SYNC.md). The short version:

1. Keep the privacy changes in their own commits on a privacy branch; never mix
   them into an upstream merge commit.
2. Rebase/merge upstream, resolve only the files listed in `SYNC.md`, keeping
   the small `privacy:` branches instead of rewriting upstream logic.
3. Run `bash privacy/check.sh`; it fails if a gate or overlay row disappears.
4. Audit new upstream telemetry/endpoints with the commands in `SYNC.md`.
5. Build with `privacy/build.sh`, then verify idle traffic on a real device.

## Known limits

- The engine overlay applies to the **local** engine only. A linked desktop DSH
  runs its own profile: set `DSH_TELEMETRY_DISABLED=1` there too if that host
  must follow the same rule. `dsh_session_log` is kept on the local engine by
  request, so a linked host that should not send it must disable it separately.
- ML Kit remains a Gradle dependency; it is never initialized, but the code is
  still linked. Removing it entirely would need an OCR/barcode replacement.
- `privacyBuild` is a Dart compile-time flag; native `PrivacyBuild` is a Kotlin
  constant. They must stay in sync.
- The overlay is patched by row id; an upstream rename silently makes a row
  disappear. `privacy/check.sh` checks the ids.
- "No third-party collection" is only true for the app process. The model
  provider, the desktop DSH, and any service you explicitly call still see what
  you send them.
