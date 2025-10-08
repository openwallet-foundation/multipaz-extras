package org.multipaz.testappextras

import io.ktor.client.engine.HttpClientEngineFactory
import io.ktor.client.engine.darwin.Darwin
import multipazextras.testapp_extras.generated.resources.Res
import multipazextras.testapp_extras.generated.resources.app_icon
import org.multipaz.prompt.IosPromptModel
import org.multipaz.prompt.PromptModel
import kotlin.experimental.ExperimentalNativeApi

actual val platformAppName = "Extras Multipaz Test App"

actual val platformAppIcon = Res.drawable.app_icon

actual val platformPromptModel: PromptModel by lazy {
    IosPromptModel()
}

@OptIn(ExperimentalNativeApi::class)
actual val platform = Platform.IOS

actual suspend fun platformInit() {
    // Nothing to do
}

actual fun platformHttpClientEngineFactory(): HttpClientEngineFactory<*> = Darwin