package io.github.ccch1mneyyy.dsh_app.privacy

/**
 * This branch is the privacy build: Google ML Kit collects SDK usage data and
 * offers no opt-out, so the app must never initialize it. Keep the one switch
 * here; every call site checks it before touching ML Kit.
 */
object PrivacyBuild {
    /** Google ML Kit collects SDK usage data and offers no opt-out. */
    const val DISABLE_ML_KIT = true

    /** OTel feedback, session-log suffix and the plugin inventory request field. */
    const val DISABLE_ENGINE_TELEMETRY = true
}
