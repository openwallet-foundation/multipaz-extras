package org.multipaz.testappextras.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import multipazextras.testapp_extras.generated.resources.Res
import multipazextras.testapp_extras.generated.resources.about_screen_title
import multipazextras.testapp_extras.generated.resources.barcode_scanning_title
import multipazextras.testapp_extras.generated.resources.camera_title
import multipazextras.testapp_extras.generated.resources.face_detection_title
import multipazextras.testapp_extras.generated.resources.face_match_title
import multipazextras.testapp_extras.generated.resources.selfie_check_title
import org.jetbrains.compose.resources.stringResource

@Composable
fun StartScreen(
    onClickAbout: () -> Unit = {},
    onClickCamera: () -> Unit = {},
    onClickFaceDetection: () -> Unit = {},
    onClickBarcodeScanning: () -> Unit = {},
    onClickSelfieCheck: () -> Unit = {},
    onClickFaceMatch: () -> Unit = {}
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier.padding(8.dp)
        ) {
            Column {
                AppUpdateCard()
            }
            LazyColumn {
                item {
                    TextButton(onClick = onClickAbout) {
                        Text(stringResource(Res.string.about_screen_title))
                    }
                }

                item {
                    TextButton(onClick = onClickCamera) {
                        Text(stringResource(Res.string.camera_title))
                    }
                }

                item {
                    TextButton(onClick = onClickFaceDetection) {
                        Text(stringResource(Res.string.face_detection_title))
                    }
                }

                item {
                    TextButton(onClick = onClickFaceMatch) {
                        Text(stringResource(Res.string.face_match_title))
                    }
                }

                item {
                    TextButton(onClick = onClickSelfieCheck) {
                        Text(stringResource(Res.string.selfie_check_title))
                    }
                }

                item {
                    TextButton(onClick = onClickBarcodeScanning) {
                        Text(stringResource(Res.string.barcode_scanning_title))
                    }
                }
            }
        }
    }
}
