package io.github.ccch1mneyyy.dsh_app.mlkit

import android.content.Context
import com.google.mlkit.common.MlKit
import io.github.ccch1mneyyy.dsh_app.privacy.PrivacyBuild

/** Called only when opening the pairing scanner or admitting an enabled OCR job. */
internal object MlKitRuntime {
    private val initialization = MlKitInitialization()

    fun initialize(context: Context) {
        // privacy: ML Kit collects SDK usage data and has no opt-out.
        check(!PrivacyBuild.DISABLE_ML_KIT) { "ML Kit is disabled in this build" }
        initialization.ensureInitialized { MlKit.initialize(context.applicationContext) }
    }
}
