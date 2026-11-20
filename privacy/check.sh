#!/usr/bin/env bash
# Static regression check for the privacy build. Run after an upstream sync.
# It cannot prove the app sends nothing; it only catches a gate disappearing.
set -euo pipefail
ROOT=$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
fail=0

forbid() {
  local file=$1 text=$2 why=$3
  if grep -Fq -- "$text" "$file"; then
    echo "UNEXPECTED: $why" >&2
    echo "  $file contains: $text" >&2
    fail=1
  fi
}

need() {
  local file=$1 text=$2 why=$3
  if ! grep -Fq -- "$text" "$file"; then
    echo "MISSING: $why" >&2
    echo "  $file does not contain: $text" >&2
    fail=1
  fi
}

need app/lib/usage/usage_net.dart 'privacyBuild ||' 'usage stats gate'
need app/lib/usage/usage_stats.dart 'usageDisabledByBuild' 'usage ledger gate'
need app/lib/privacy/privacy_build.dart "DSH_PRIVACY" 'Dart privacy flag'
need app/lib/state/update_state.dart 'privacyBuild' 'update gate'
need app/lib/state/update_state.dart 'if (privacyBuild) return UpdateCheckPhase.idle' 'manual update check gate'
need app/lib/state/update_state.dart 'if (privacyBuild) return false' 'automatic update check gate'
need app/lib/ui/update/update_tiles.dart 'privacyBuild' 'update UI gate'
need app/lib/ui/remote/pairing_page.dart 'privacyBuild' 'pairing scanner gate'
need app/lib/state/plugins/plugin_market.dart 'privacyBuild' 'market offline gate'
need app/lib/ui/plugins/plugins_screen.dart 'privacyBuild' 'market tab gate'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/privacy/PrivacyBuild.kt 'DISABLE_ML_KIT' 'native ML Kit flag'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/mlkit/MlKitRuntime.kt 'PrivacyBuild.DISABLE_ML_KIT' 'ML Kit runtime gate'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/a11y/MlKitLocalOcr.kt 'PrivacyBuild.DISABLE_ML_KIT' 'OCR gate'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/RuntimeController.kt 'DSH_TELEMETRY_DISABLED' 'engine OTel gate'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/AppAuthGuest.kt 'id: plugin-package-inventory-deepseek' 'plugin inventory overlay'
forbid app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/AppAuthGuest.kt 'id: session-log-deepseek' 'session-log must stay enabled'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/AppAuthGuest.kt 'id: session-telemetry-otel' 'OTel overlay'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/AppAuthGuest.kt 'id: command-feedback' 'feedback command overlay'
need app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/AppAuthGuest.kt 'id: message-feedback' 'message feedback overlay'
need privacy/build.sh 'DSH_PRIVACY=1' 'build wrapper'

if ((fail)); then
  echo "privacy check failed" >&2
  exit 1
fi
echo "privacy gates present"
