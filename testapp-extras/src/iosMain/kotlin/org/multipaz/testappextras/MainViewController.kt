package org.multipaz.testappextras

import androidx.compose.ui.window.ComposeUIViewController

private val app = App.getInstance()

/** Used by XCode for iOS app building. */
fun MainViewController() = ComposeUIViewController {
    app.Content()
}