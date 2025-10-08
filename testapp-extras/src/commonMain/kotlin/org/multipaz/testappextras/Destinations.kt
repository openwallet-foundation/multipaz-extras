package org.multipaz.testappextras

import multipazextras.testapp_extras.generated.resources.Res
import multipazextras.testapp_extras.generated.resources.about_screen_title
import multipazextras.testapp_extras.generated.resources.barcode_scanning_title
import multipazextras.testapp_extras.generated.resources.camera_title
import multipazextras.testapp_extras.generated.resources.face_detection_title
import multipazextras.testapp_extras.generated.resources.face_match_title
import multipazextras.testapp_extras.generated.resources.selfie_check_title
import org.jetbrains.compose.resources.StringResource

sealed interface Destination {
    val route: String
    val title: StringResource?
}

data object StartDestination : Destination {
    override val route = "start"
    override val title = null
}

data object AboutDestination : Destination {
    override val route = "about"
    override val title = Res.string.about_screen_title
}

data object CameraDestination : Destination {
    override val route = "camera"
    override val title = Res.string.camera_title
}

data object FaceDetectionDestination : Destination {
    override val route = "face_detection"
    override val title = Res.string.face_detection_title
}

data object BarcodeScanningDestination : Destination {
    override val route = "BarcodeScanning"
    override val title = Res.string.barcode_scanning_title
}

data object SelfieCheckScreenDestination : Destination {
    override val route = "SelfieCheck"
    override val title = Res.string.selfie_check_title
}

data object FaceMatchScreenDestination : Destination {
    override val route = "FaceMatch"
    override val title = Res.string.face_match_title
}

val appDestinations = listOf(
    StartDestination,
    AboutDestination,
    CameraDestination,
    FaceDetectionDestination,
    FaceMatchScreenDestination,
    SelfieCheckScreenDestination,
    BarcodeScanningDestination,
)