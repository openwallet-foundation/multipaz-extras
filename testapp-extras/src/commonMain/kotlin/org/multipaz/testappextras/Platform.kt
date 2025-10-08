package org.multipaz.testappextras

import io.ktor.client.engine.HttpClientEngineFactory
import org.jetbrains.compose.resources.DrawableResource
import org.multipaz.prompt.PromptModel

enum class Platform(val displayName: String) {
    ANDROID("Android"),
    IOS("iOS")
}

expect val platformAppName: String

expect val platformAppIcon: DrawableResource

expect val platformPromptModel: PromptModel

expect val platform: Platform

expect val platformIsEmulator: Boolean

expect suspend fun platformInit()

expect fun platformHttpClientEngineFactory(): HttpClientEngineFactory<*>
